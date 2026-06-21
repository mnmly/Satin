# Satin 2.0 Changelog

## Metal 4 Backend Support

Satin now has incremental Metal 4 frame-command support for renderer-owned render, post-process, shadow, and compute paths. `Context(device:backend:...)` accepts `.metal4` and falls back to `.metal3` when Metal 4 command queues are not available.

📖 **See [Documentation/Metal4Backend.md](Documentation/Metal4Backend.md) for the full migration guide, override expectations, known limitations, and perf characteristics.**

Metal 4 render argument tables are pooled per frame slot and render pass, and bound resources are tracked through a per-frame residency set for explicit `gpuAddress` / `gpuResourceID` usage.

Third-party compute subclasses can use the backend-neutral `ComputeArgumentBinding` surface instead of depending on Satin's internal Metal 4 argument-table type:

- `ComputeProcessor.preComputeBinding`
- `ComputeSystem.preComputeBinding`
- `TextureComputeSystem.bind(_ binding:iteration:)`
- `BufferComputeSystem.bind(_ binding:)`

Legacy `MTLComputeCommandEncoder` hooks remain available for Metal 3 paths.

`SpatialRenderer` now supports the Metal 4 backend on visionOS 26+ via the new
`cp_layer_renderer_get_mtl4_command_queue` and `cp_drawable_t.encodePresent(self:)`
compositor APIs. Pass `backend: .metal4` to the Satin `Context` and Satin will
route frame commands through the layer renderer's MTL4 queue. Parallel
`preDrawMetal4`, `draw(frame:drawable:frameCommand:cameras:)`,
`postDraw(...frameCommand:)`, and `drawView(...frameCommand:)` overloads exist;
the existing `MTLCommandBuffer`-taking methods continue to work for visionOS < 26
and for pinning to Metal 3.

`Context.init` gained an `externalMetal4CommandQueue: Any? = nil` parameter
(erased to `Any?` so the initializer stays available on pre-OS-26 callers).
When non-nil and `backend == .metal4`, Satin's `Metal4Support` adopts that queue
instead of creating its own. Used by `SpatialRenderer.makeDefaultContext` to
hand the compositor's queue into the Satin renderer stack.

Known fallback boundaries:

- Metal Performance Shaders blur, upscale, and AR matte paths still require `MTLCommandBuffer`; their frame-command overloads return `false` or `nil` for Metal 4 commands so callers can fall back explicitly.
- visionOS Simulator does not expose MTL4 types — build for visionOS device or pin the simulator target to `.metal3`.

### Backend Fixes & Hardening

- **Argument tables sized for the full binding layout.** The fragment argument table now spans every directional-shadow texture (`DirectShadow0 + maxShadowTextures`) and projector slot. Scenes with more than one shadowed directional light previously exceeded the table, failed the binding, and silently re-rendered every frame on the Metal 3 fallback — they now stay on Metal 4. Dirty-slot tracking was widened past 64 slots to match.
- **Bindings keyed by raw index against each table's real capacity** instead of fixed index enums, reconciling the previously-disagreeing limits. Custom material binding indices within capacity now bind on Metal 4 rather than forcing the fallback.
- **`Metal4Support` is allocated lazily.** The MTL4 queue, command allocators, and residency sets are created on first frame-command use, so the many `Context` values the renderer derives to key pipeline compilation no longer each allocate an unused backend. `Context.backend` is derived from a device-capability check.
- **`SatinFrameCommand.metal3CommandBuffer`** exposes the classic command buffer (nil on Metal 4). Per-frame encoders that depend on `MTLCommandBuffer`-only APIs (e.g. MPS) should `guard let commandBuffer = frameCommand.metal3CommandBuffer` instead of casting to `MetalFrameCommand`.

## Architecture Refactor — Encoder / Orchestrator Split (Breaking)

The old `Renderer` class was conflating two unrelated responsibilities: encoding a scene graph into a `MTLCommandBuffer`, and owning the render loop (display link, command queue, semaphore, frame index). These are now separated into two distinct tiers.

### Tier 1 — Encoders

Classes that encode work into a `MTLCommandBuffer`. They have no display link, no command queue, and no frame index.

| Old name | New name |
|---|---|
| `Renderer` | `RenderEncoder` |
| `PostProcessor` | `PostProcessEncoder` |
| `SsaoPostProcessor` | `SsaoPostProcessEncoder` |
| `SsgiPostProcessor` | `SsgiPostProcessEncoder` |
| `MotionBlurPostProcessor` | `MotionBlurPostProcessEncoder` |
| `BokehDepthOfFieldPostProcessor` | `BokehDepthOfFieldPostProcessEncoder` |
| `ARBackgroundRenderer` | `ARBackgroundEncoder` |
| `ARBackgroundDepthRenderer` | `ARBackgroundDepthEncoder` |
| `ARMatteRenderer` | `ARMatteEncoder` |
| `ARPostProcessor` | `ARPostProcessEncoder` |

`RenderEncoder` has no backward-compatibility typealias — the name `Renderer` is taken by the new orchestrator base. All call sites must migrate from `Renderer(context:)` to `RenderEncoder(context:)`.

### Tier 2 — Render Drivers

Classes that own the render loop: display link, command queue, GPU sync semaphore, and frame index.

**New `Renderer` abstract base** (`Sources/Satin/Views/Renderer.swift`) consolidates the shared infrastructure that was previously duplicated between `MetalViewRenderer` and `MetalLayerRenderer`:

- `context: Context` — set at init
- `frameIndex: Int` — starts at -1, incremented each frame
- `inFlightSemaphore` — GPU/CPU synchronisation, value = `maxBuffersInFlight`
- Per-slot texture caches: `colorMultisampleTextures`, `depthTextures`, `depthMultisampleTextures`, `stencilTextures`, `stencilMultisampleTextures`
- Storage mode / usage overrides for color, depth, and stencil textures
- Frame encoding: `preDraw() -> MTLCommandBuffer?`, `draw(texture:commandBuffer:)`, `draw(renderPassDescriptor:commandBuffer:)`, `postDraw(commandBuffer:)`
- Texture helpers: `getDepthTexture`, `getMultisampleDepthTexture`, `getStencilTexture`, `getMultisampleStencilTexture`, `getMultisampleColorTexture`
- Lifecycle stubs: `setup()`, `update()`, `cleanup()`, `resize(size:scaleFactor:)`
- `defaultContext` — convenience accessor for a single-sample context derived from the renderer's context

| Old name | New name | Notes |
|---|---|---|
| *(new)* | `Renderer` | Abstract base; owns render loop infrastructure |
| `MetalViewRenderer` | `ViewRenderer` | Subclasses `Renderer`; owns `MetalView` and input event stubs |
| `MetalLayerRenderer` | `SpatialRenderer` | Subclasses `Renderer`; owns `LayerRenderer` and visionOS AR session |

`MetalViewController` now accepts a `ViewRenderer` (previously `MetalViewRenderer`).

### Migration

- Replace `Renderer(context:)` with `RenderEncoder(context:)` at all call sites.
- Replace `MetalViewRenderer` with `ViewRenderer`.
- Replace `MetalLayerRenderer` with `SpatialRenderer`.
- Replace `PostProcessor` with `PostProcessEncoder` and its subclasses accordingly.
- Replace all `AR*Renderer` / `ARPostProcessor` references with the `*Encoder` equivalents.
- Example utility base classes: `BaseRenderer: MetalViewRenderer` → `BaseRenderer: ViewRenderer`; `ImmersiveBaseRenderer: MetalLayerRenderer` → `ImmersiveBaseRenderer: SpatialRenderer`.

---

## Context Init

In Satin 1.0, an object’s `Context` could change out from under it (was a var) causing some subtle issues, and `Context` was assigned lazily. In Satin 2.0, all objects have a let `Context`, thus requiring new initializers. This change fixes a class of bugs, and for most use cases, a Satin `Context` does not change, so we decided this would be an acceptable change. 

## Renderer Clarification

In Satin 1.0, there were a few classes with the name ‘Renderer’ which served different roles. In Satin 2.0, we wanted to simplify and clarify class names by their responsibilities. We now have a suite of `RenderEncoder` objects, and a suite of `Renderer` objects.

***Render Encoder Class Responsibilities***
* Handling Satin specific scene graph traversal
* Ordering passes based on material, lighting and shadow needs
* Encoding commands to a command buffer

***Renderer Responsibilities***
* Handling draw loops / display links and eventually threading
* Handling Metal Surfaces 
* Integrating with platform specific views

### RenderEncoders

Classes that encode work into a `MTLCommandBuffer`. They have no display link, no command queue, and no frame index.

| Old name | New name |
|---|---|
| `Renderer` | `RenderEncoder` |
| `PostProcessor` | `PostProcessEncoder` |
| `ARBackgroundRenderer` | `ARBackgroundEncoder` |
| `ARBackgroundDepthRenderer` | `ARBackgroundDepthEncoder` |
| `ARMatteRenderer` | `ARMatteEncoder` |
| `ARPostProcessor` | `ARPostProcessEncoder` |

New Render Post Process Encoders

| Class | Description |
|---|---|
| `SsaoPostProcessEncoder` | Applies Screen Space Ambient Occlusion |
| `MotionBlurPostProcessEncoder` | Applies velocity map motion blur |
| `BokehDepthOfFieldPostProcessEncoder` | Applies fast separable depth of field blur |
| `SsgiPostProcessEncoder` | Applies experimental Screen Space Global Illumination | 


### Renderers

Classes that own the render loop: display link, command queue, GPU sync semaphore, and frame index.

**New `Renderer` abstract base** (`Sources/Satin/Views/Renderer.swift`) consolidates the shared infrastructure that was previously duplicated between `MetalViewRenderer` and `MetalLayerRenderer`:

| Old name | New name | Notes |
|---|---|---|
| *(new)* | `Renderer` | Abstract base; owns render loop infrastructure |
| `MetalViewRenderer` | `ViewRenderer` | Subclasses `Renderer`; owns `MetalView` and input event stubs |
| `MetalLayerRenderer` | `SpatialRenderer` | Subclasses `Renderer`; owns `LayerRenderer` and visionOS AR session |

`MetalViewController` now accepts a `ViewRenderer` (previously `MetalViewRenderer`).

---

## Updated Lighting / Shadows

All three light types — `DirectionalLight`, `PointLight`, and `SpotLight` — now support shadow casting. Enable shadows on any light by setting `castShadow = true`. Each light type gets its own shadow class (`DirectionalShadow`, `PointShadow`, `SpotShadow`) with tunable parameters:

```swift
let spot = SpotLight(context: context, color: .one, intensity: 2.0, radius: 8.0, angleInner: 30.0, angleOuter: 45.0)
spot.castShadow = true
spot.shadow.resolution = (width: 2048, height: 2048)
spot.shadow.bias = 0.00005
spot.shadow.strength = 0.8
```

`SpotLight` additionally supports a `projectionTexture` for cookie and projector effects, controlled by `projectionMode`:

- `.mask` — the texture modulates the spot's intensity (cookie / gobo effect)
- `.color` — the texture's RGB is projected as colored light onto shadow-receiving geometry

```swift
spot.projectionTexture = myTexture
spot.projectionMode = .color   // or .mask
```

---

## Render Mode support

Satin now supports three rendering modes: `forward`, `forwardPlus`, and `deferredGeometry`.

**`forward`** is the simplest mode: one pass, one color output. Use it when you don't need any post-processing that requires surface data (normals, PBR properties, velocity).

**`forwardPlus`** renders geometry in a single pass but simultaneously writes auxiliary surface data — albedo, normals, PBR, velocity, emissive — to additional render targets alongside color. Use this when you want post-process effects (SSAO, SSGI, motion blur, depth of field) without the overhead of a separate geometry prepass.

**`deferredGeometry`** splits rendering into two passes: a geometry pass that writes surface properties to a G-buffer, followed by a fullscreen lighting resolve pass. Unlit materials always render in a subsequent forward pass on top. Use this for scenes with many dynamic lights where the deferred lighting model reduces per-fragment work.

Enabling `forwardPlus` or `deferredGeometry` unlocks auxiliary G-buffer outputs alongside the color attachment. Only enable outputs that are actually consumed by a post-processor — each active flag costs a texture allocation and a color attachment write per fragment.

```swift
let context = Context(
    device: device,
    sampleCount: 1,
    colorPixelFormat: .bgra8Unorm,
    depthPixelFormat: .depth32Float,
    renderingMode: .forwardPlus,
    activeOutputs: [.color, .normals, .velocity]
)
```

`activeOutputs` is an `OptionSet` (`RendererOutputs`). Available flags: `.color` (always present), `.albedo`, `.normals`, `.pbr`, `.velocity`, `.emissive`. The `RenderEncoder` inherits `activeOutputs` from the Context; you can reassign it after construction, but doing so triggers pipeline recompilation on the next frame. MRT output requires `sampleCount == 1`.

### Custom Material Shader API

All Satin surface materials have been updated to write to a `SurfaceOutput` struct. Custom surface materials implement `evaluateSurface()` and populate it — the framework handles lighting and routes the result to the correct G-buffer attachments via `buildFragmentOutput()`. Unlit materials skip `SurfaceOutput` entirely and return a `FragmentOutput` directly using `buildColorFragmentOutput()`. The active attachments in `FragmentOutput` are controlled at compile time by `OUTPUT_*` preprocessor defines injected from the Context, so custom shaders don't need to conditionally compile against each mode manually.

---

## Alpha Order-Independent Transparency

Satin now supports Apple image-block order-independent transparency (OIT), which solves the classic problem of alpha-blended objects rendering incorrectly without CPU depth sorting. Enable it by passing `alphaOitEnabled: true` to `Context`.

When enabled, `blending = .alpha` uses Apple’s tile-memory image-block API on `MTLGPUFamilyApple4` GPUs (A11 Bionic / M1 and later). Alpha-blended content renders correctly in `forward`, `forwardPlus`, and `deferredGeometry` without requiring CPU depth sorting. On unsupported hardware, `.alpha` falls back to classic hardware alpha blending (order-dependent).

### Behavior

| Blend mode | Internal path | Notes |
|---|---|---|
| `disabled` | Opaque | Existing behavior |
| `alpha` | Apple image-block alpha OIT | Apple4+ only; unsupported hardware falls back to classic alpha |
| `additive` | Classic hardware blending | Always order-dependent; drawn after alpha OIT |
| `subtract` | Classic hardware blending | Always order-dependent; drawn after alpha OIT |
| `custom` | Classic hardware blending | Always order-dependent; drawn after alpha OIT |


### Notes

- Alpha OIT writes only to the `color` attachment. Transparent alpha materials still do not contribute to `albedo`, `normals`, `pbr`, `velocity`, or `emissive`.
- Bucket order is fixed: `opaque → alpha OIT → classic transparent`. Classic transparent draws always appear over resolved alpha-OIT content regardless of `renderOrder`.
- Custom `SourceMaterial` shaders can opt into alpha OIT by defining `SATIN_ALPHA_OIT_ENABLED`, including `FragmentOutput.metal`, and returning `FragmentOutput` through `buildColorFragmentOutput(...)`.

## Point Geometry Rendering

All core materials now support point primitive rendering. Set `geometry.primitiveType = .point` on any mesh — no material swap required.

### API

Every material gains a `pointSize: Float` property (default `1.0`):

```swift
let mesh = Mesh(context: context, geometry: myGeo, material: BasicColorMaterial(context: context))
mesh.geometry.primitiveType = .point
mesh.material.pointSize = 8.0
```

### Supported Materials

| Material | Opt-in required | Notes |
|---|---|---|
| `BasicColorMaterial` | No | Solid color points |
| `BasicTextureMaterial` | No | Samples texture at vertex UV |
| `DepthMaterial` | No | Depth-encoded points |
| `UVColorMaterial` | No | UV-as-color points |
| `NormalColorMaterial` | No | Normal-as-color points |
| `StandardMaterial` | No | Full PBR — each point lit by its vertex normal |
| `PhysicalMaterial` | No | Full advanced PBR — inherits from Standard |

> For circular/masked points with per-fragment UV control, `BasicPointMaterial` remains the dedicated option.

`[[point_size]]` is ignored by the Metal rasterizer for non-point primitives, so all existing triangle rendering is unaffected. `pointSize` serializes automatically via the `ParameterGroup` Codable path — no migration needed.

## Text Rendering

Satin 2.0 gets the now open source SLUG rendering API ported from Warren Moore’s MetalSlug example. 

This is a great option to replace 1d SDF surface text rendering. See `SlugTextMesh` `SlugTextGeometry` `SlugTextMaterial` and `SlugFontAtlas` or the example `SlugTextRenderer`

## Performance Improvements

Satin 2.0 replaces some protocol-based types with concrete base classes on performance-critical paths, eliminating Swift Protocol Witness Table overhead.

Satin 2.0 adopts `CAMetalDisplayLink` on our new Mac based views, which removes some overhead of CAMetalDrawable creation. 

Internally to our main `RenderEncoder` class, we remove some cases of temporary array creation, optimize object hashing, and optimize some dictionaries and keys for pass management. 

Model loading now collapses object hierarchies which do not have meshes, reducing the graph size / object traversal and matrix calculations needed for rendering larger more complicated models substantially. 

## Bug Fixes

* Fix a bug in text tessellation, improving some edge cases with certain fonts not rendering correctly
* Fix a bug with Parametric Geometry having reversed normals
* Fix bug with anisotropic rendering
* Fix a bug with some UV’s in geometry generators
* Add texture matrix support for all materials which consume textures.