# Satin Metal 4 Backend

Satin supports the Metal 4 frame-command model as an **opt-in backend** alongside the classic Metal 3 command-buffer model. This document covers what changes when you switch, what stays the same, what isn't supported yet, and how third-party code should adapt.

## Contents

- [TL;DR](#tldr)
- [Opting in](#opting-in)
- [Fallback behavior](#fallback-behavior)
- [What changes for callers](#what-changes-for-callers)
  - [Public draw entry points](#public-draw-entry-points)
  - [Auto-allocation of render-target textures](#auto-allocation-of-render-target-textures)
  - [Frame-command lifecycle](#frame-command-lifecycle)
- [What changes for subclassers](#what-changes-for-subclassers)
- [Known limitations](#known-limitations)
- [Performance characteristics](#performance-characteristics)
- [Examples](#examples)
- [Migration checklist](#migration-checklist)

---

## TL;DR

```swift
// Before
let context = Context.makePlatformDefault()                       // Metal 3

// After
let context = Context.makePlatformDefault(backend: .metal4)       // Metal 4 (falls back to Metal 3 if unsupported)
```

Everything else — `RenderEncoder`, `Mesh`, materials, shadows, post-processing — has the same public surface on both backends. The Metal 4 backend uses argument tables, command allocators, residency sets, and a shared event for the Metal 3 fallback path; all of that is internal.

Run the test suite (`Tests/SatinTests/RendererFrameCommandTests.swift`) for end-to-end coverage of the Metal 4 paths, and `Metal4BackendPerfTests` for a Metal 3 vs Metal 4 wall-clock comparison.

---

## Opting in

The backend is selected per-`Context`:

```swift
let context = Context(
    device: device,
    backend: .metal4,                 // <- new
    sampleCount: 1,
    colorPixelFormat: .bgra8Unorm,
    depthPixelFormat: .depth32Float
)
// context.requestedBackend == .metal4 always
// context.backend == .metal4 only if the device supports it
```

Or via the convenience factory:

```swift
let context = Context.makePlatformDefault(backend: .metal4)
```

**Hardware requirements**

`Context.makeMetal4Support` checks `device.supportsFamily(.metal4)` before instantiating any MTL4 objects. Per Apple's [Metal Feature Set Tables](https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf), that family covers **Apple7 silicon and newer** (M1, A14, and later) on macOS / iOS / visionOS 26.0. Older Apple GPUs, AMD discrete GPUs, and Intel integrated GPUs do not report `.metal4`.

The opt-in is also OS-gated: even on supported hardware, Metal 4 requires the OS 26 SDK at runtime (`@available(macOS 26.0, iOS 26.0, visionOS 26.0, *)`).

---

## Fallback behavior

Requesting `.metal4` on a device or OS that doesn't support it does **not** crash. `Context.backend` reports what's actually in use; `Context.requestedBackend` is what the caller asked for.

```swift
let context = Context(device: device, backend: .metal4, ...)
print(context.requestedBackend)  // .metal4
print(context.backend)           // .metal4 on M1+/OS 26+, .metal3 otherwise
```

There is also a **runtime mid-frame fallback**: if a Metal 4 draw fails part-way through (e.g. an argument-table binding outside the supported range, a missing render encoder, an unsupported tessellation call), `RenderEncoder` reports the failure on `lastFrameCommandDrawFailure` and `ViewRenderer` automatically:

1. Commits the partial Metal 4 command buffer.
2. Creates a fresh Metal 3 command buffer.
3. Re-renders the scene on Metal 3.
4. Synchronises the two queues through an `MTLSharedEvent` so the Metal 3 work waits for the Metal 4 partial work to finish before touching the drawable.

This makes it safe to ship a Metal 4 build to fleet hardware that has occasional Metal 4-incompatible content — the fallback drops a frame's worth of perf, not the whole render.

---

## What changes for callers

### Public draw entry points

Two `RenderEncoder.draw(...)` overloads exist and both end up in the same unified core:

```swift
// Classic — still works, wraps the command buffer in a Metal 3 frame command internally.
public func draw(
    renderPassDescriptor: MTLRenderPassDescriptor,
    commandBuffer: MTLCommandBuffer,
    scene: Object,
    cameras: [Camera],
    viewports: [MTLViewport],
    viewMappings: [MTLVertexAmplificationViewMapping] = []
)

// Frame-command — accepts either backend's frame command, returns false on failure.
@discardableResult
public func draw(
    renderPassDescriptor: MTLRenderPassDescriptor,
    frameCommand: any SatinFrameCommand,
    scene: Object,
    cameras: [Camera],
    viewports: [MTLViewport],
    viewMappings: [MTLVertexAmplificationViewMapping] = []
) -> Bool
```

For Metal 4, you obtain a frame command from the renderer:

```swift
class MyRenderer: ViewRenderer {
    override func draw(renderPassDescriptor: MTLRenderPassDescriptor, frameCommand: any SatinFrameCommand) -> Bool {
        renderer.draw(
            renderPassDescriptor: renderPassDescriptor,
            frameCommand: frameCommand,
            scene: scene,
            camera: camera
        )
    }
}
```

`ViewRenderer.draw(metalLayer:drawable:)` picks the right overload based on the context's backend; you generally don't need to call `makeFrameCommand()` yourself.

### Auto-allocation of render-target textures

Both backends now auto-allocate color, depth, stencil, and multisample textures when the supplied `renderPassDescriptor` doesn't include them. Previously the Metal 4 path errored if textures weren't supplied; that requirement is gone — the Metal 3 ergonomics carry over.

If you do supply your own textures, both backends honour them; the renderer never reallocates over a caller-provided texture of the correct size.

### Frame-command lifecycle

Internally, the Metal 4 path uses:

- **Per-slot `MTL4CommandAllocator`** — one per `maxBuffersInFlight` slot, reset at the start of each frame on that slot.
- **Per-slot `MTLResidencySet`** — `useResidencySet` is attached to the command buffer; argument-table setters auto-register every bound buffer and texture so the resource is resident before the GPU executes.
- **Per-slot `DispatchSemaphore`** — guarantees allocator/residency reset only happens after the GPU has finished using that slot's resources, even if a caller bypasses `Renderer.commitFrameCommand`.
- **Pooled argument tables** — `Metal4ArgumentTablePool` reuses argument-table instances per (frame slot, pass cursor) instead of allocating them per frame. The pool clears dirty slots on reuse via bitset tracking (one bitwise-OR per bind, O(used) drain on reuse).
- **Shared event for fallback** — a single `MTLSharedEvent` fences any MTL3 fallback work against the partial MTL4 buffer; see [Fallback behavior](#fallback-behavior).

All of this is internal. The only public surface a Metal 4 caller needs is `frameCommand: any SatinFrameCommand`.

---

## What changes for subclassers

`Object`, `Material`, and `Geometry` expose **two per-frame encode hooks**:

```swift
// Legacy — Metal 3 only. Override for backwards-compatible per-frame compute.
open func encode(_ commandBuffer: MTLCommandBuffer)

// Backend-agnostic. Override for Metal-4-aware per-frame compute.
open func encode(frameCommand: any SatinFrameCommand)
```

The default `encode(frameCommand:)` unwraps a `MetalFrameCommand` and forwards to `encode(_:)`. **On Metal 4 it is a no-op** unless you override it.

**If you don't do per-frame compute** (most subclasses), you don't need to do anything.

**If you do per-frame compute** (regenerating geometry, updating an instance buffer via blit, etc.), override **both**:

```swift
class MyAnimatedMesh: Mesh {
    override func encode(_ commandBuffer: MTLCommandBuffer) {
        super.encode(commandBuffer)
        regenerateVertexData(commandBuffer)
    }

    override func encode(frameCommand: any SatinFrameCommand) {
        super.encode(frameCommand: frameCommand)
        if let metal3 = frameCommand as? MetalFrameCommand {
            regenerateVertexData(metal3.commandBuffer)
        } else if #available(macOS 26.0, iOS 26.0, visionOS 26.0, *),
                  let metal4 = frameCommand as? Metal4FrameCommand,
                  let computeEncoder = metal4.commandBuffer.makeComputeCommandEncoder()
        {
            regenerateVertexData(computeEncoder)
            computeEncoder.endEncoding()
        }
    }
}
```

Mesh, TessellationMesh, ARLidarMesh, and ParametricGeometry all override both already.

For **`ComputeProcessor` / `ComputeSystem`** subclasses, the canonical override is now `update(_ frameCommand: any SatinFrameCommand, iterations:)` and the inner `bind(_:)` / `dispatch(metal4ComputeEncoder:pipeline:iteration:)` / `dispatchThreadgroups(metal4ComputeEncoder:pipeline:iteration:)` hooks. The base class provides Metal 3 implementations; subclasses that want Metal 4 support override the metal4-specific dispatch methods.

---

## Known limitations

These are tracked at known issues; none of them cause crashes — the renderer fails the Metal 4 path cleanly and (for render encoders) the MTL3 fallback takes over.

| Feature | Status | Why |
|---|---|---|
| Tessellation | Not supported on Metal 4 | `MTL4RenderCommandEncoder` does not yet expose `setTessellationFactorBuffer` / `drawPatches` / `drawIndexedPatches`. `RenderEncoderState` calls `failEncoding(...)` on Metal 4, which trips the MTL3 fallback. |
| `CubemapGenerator(sigma > 0)` | MTL3 only | Uses `MPSImageGaussianBlur`, which doesn't accept an `MTL4CommandBuffer`. `encode(frameCommand:)` returns false for the blur path; the `sigma == 0` path works on both backends. |
| `ARBackgroundDepthEncoder`, `ARFeatheredDepthMaskGenerator`, `ARDepthUpscaler`, `ARMatteEncoder` | MTL3 only | All depend on Metal Performance Shaders kernels that take `MTLCommandBuffer`. They explicitly guard `frameCommand as? MetalFrameCommand` and return false on Metal 4. |
| visionOS `SpatialRenderer` compositor | MTL3 only | `LayerRenderer.Drawable.encodePresent(commandBuffer:)` still takes an `MTLCommandBuffer`. The compositor pins its render context to Metal 3 even when the scene rendering uses Metal 4. |
| Vertex amplification count > 2 | Not supported on Metal 4 | `drawMetal4Forward` rejects amplification counts above 2. Custom view mappings *are* now supported (synthesised identity mappings on visionOS stereo). |
| `Metal4RenderCommandEncoder.useResource` | Forwarded to argument table residency | Direct `useResource` is implemented via argument-table residency-set add. Heap-backed resources that aren't bound through argument tables would need explicit residency-set tracking by the caller. |

---

## Performance characteristics

`Metal4BackendPerfTests` runs the same offscreen scene through both backends. Sample numbers on M-series silicon at 512×512 with the bitset-tracked argument-table dirty-slot optimisation:

| Scene | Metal 3 | Metal 4 | Delta |
|---|---|---|---|
| Small forward (100 meshes) | 1.77 ms/frame | 1.76 ms/frame | +0.5% MTL4 |
| Large forward (1024 meshes) | 15.81 ms/frame | 15.66 ms/frame | +0.9% MTL4 |
| Deferred (256 PBR meshes) | 5.76 ms/frame | 5.71 ms/frame | +0.7% MTL4 |
| Forward + directional shadow | 5.46 ms/frame | 5.57 ms/frame | -2.0% MTL4 |

**Where Metal 4 wins.** Scenes with high binding traffic (large mesh counts, many materials) amortise the per-frame allocator / residency-set bookkeeping. The argument-table model also benefits future workloads with many bindless lookups.

**Where Metal 4 loses today.** Scenes with multiple render encoders per frame (shadow casting, deferred lighting + many G-buffer attachments). Each Metal 4 render encoder requires bridging `MTLRenderPassDescriptor` → `MTL4RenderPassDescriptor` (~1.7 µs) and acquiring argument tables from the pool. With a single main pass this is invisible; with a shadow + main pass it adds up.

**Future wins.** Metal 4's headline features — multi-threaded command encoding, indirect command buffers with memory barriers, dedicated compilation contexts, pipeline dataset serialisation, machine-learning encoding — are **not yet exposed through Satin's public API**. The current Metal 4 backend is a "same surface, new backend" effort. See the [CHANGELOG](../CHANGELOG.md) for what's actually shipping vs aspirational.

---

## Examples

In `Example/Example/Renderers/Basics/`:

- **`Metal4BackendRenderer`** — minimal sphere + floor scene on Metal 4. Smallest possible opt-in demo.
- **`Metal4DirectionalShadowRenderer`** — shadow-casting scene on Metal 4. Exercises shadow caster + receiver path through argument tables and residency sets.
- **`Metal4DeferredRenderer`** — three PBR spheres + ground in `renderingMode: .deferredGeometry`. Exercises the surface MRT pass, deferred lighting resolve, and BasicDiffuse fallback through the unified MTL3/MTL4 orchestration.

All three live under the **"Metal 4"** section of the example app sidebar.

---

## Migration checklist

For existing Satin-based apps wanting to opt into Metal 4:

1. **Change one line** — `Context.makePlatformDefault(backend: .metal4)` (or pass `backend: .metal4` to your existing `Context(...)` initialiser).
2. **Run on Apple7+ hardware** with OS 26+ — the device-family gate falls back transparently elsewhere, but the new code only exercises on supported devices.
3. **If you subclass `Object`/`Material`/`Geometry`** and override `encode(_ commandBuffer:)` for per-frame compute, also override `encode(frameCommand:)` — see [What changes for subclassers](#what-changes-for-subclassers).
4. **If you use `MPSImage*` directly** in your own per-frame encoders, gate them on `frameCommand as? MetalFrameCommand` and provide a Metal-4-native path (or accept the MTL3 fallback for that subgraph).
5. **If you set custom sample positions** via `MTLRenderPassDescriptor.setSamplePositions(_:)`, they are now forwarded to the MTL4 descriptor automatically.
6. **If you use tessellation**, the Metal 4 path will fail through to the MTL3 fallback for any frame that needs `drawPatches`. Expect occasional one-frame stalls when tessellated geometry first appears.
7. **Run the perf tests** with `swift test --filter Metal4BackendPerfTests` to see how your specific scene shape compares. Small scenes may favour MTL3; binding-heavy scenes typically favour MTL4.
8. **Read the [CHANGELOG](../CHANGELOG.md)** for the full list of Metal 4 behaviour changes.

If you hit a Metal 4 failure mode the fallback can't recover from, please open an issue with `lastFrameCommandDrawFailure` and a minimal repro.
