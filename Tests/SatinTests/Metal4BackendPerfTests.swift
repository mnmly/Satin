import Foundation
import Metal
@testable import Satin
import XCTest

/// Side-by-side wall-clock timing for the same offscreen scene on Metal 3 vs Metal 4
/// frame commands. Run with:
///
///   swift test --filter Metal4BackendPerfTests
///
/// Output is printed (not asserted) so the harness can run on CI without false
/// negatives from noise. Each invocation reports per-frame median and total time
/// for both backends plus the ratio.
final class Metal4BackendPerfTests: XCTestCase {
    private static let renderTargetSize = SIMD2<Int>(512, 512)

    func testSmallForwardScene() throws {
        try runComparison(
            label: "Small forward (100 meshes, no shadows)",
            frames: 200,
            warmup: 5,
            buildScene: makeForwardScene(meshCount: 100, withShadows: false),
            renderingMode: .forward
        )
    }

    func testLargeForwardScene() throws {
        try runComparison(
            label: "Large forward (1024 meshes, no shadows)",
            frames: 100,
            warmup: 5,
            buildScene: makeForwardScene(meshCount: 1024, withShadows: false),
            renderingMode: .forward
        )
    }

    func testForwardWithDirectionalShadow() throws {
        try runComparison(
            label: "Forward + directional shadow (256 meshes)",
            frames: 100,
            warmup: 5,
            buildScene: makeForwardScene(meshCount: 256, withShadows: true),
            renderingMode: .forward
        )
    }

    func testDeferredScene() throws {
        try runComparison(
            label: "Deferred geometry (256 PBR meshes)",
            frames: 100,
            warmup: 5,
            buildScene: makeDeferredScene(meshCount: 256),
            renderingMode: .deferredGeometry
        )
    }

    // MARK: - Comparison harness

    private struct SceneBuild {
        let scene: Object
        let camera: Camera
    }

    private func runComparison(
        label: String,
        frames: Int,
        warmup: Int,
        buildScene: (Context) -> SceneBuild,
        renderingMode: RenderingMode
    ) throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal is unavailable on this machine.")
        }
        guard device.supportsFamily(.metal4) else {
            throw XCTSkip("Device does not support MTLGPUFamily.metal4.")
        }

        let metal3 = try runScene(
            device: device,
            backend: .metal3,
            frames: frames,
            warmup: warmup,
            renderingMode: renderingMode,
            buildScene: buildScene
        )
        let metal4 = try runScene(
            device: device,
            backend: .metal4,
            frames: frames,
            warmup: warmup,
            renderingMode: renderingMode,
            buildScene: buildScene
        )

        let perFrame3 = metal3 / Double(frames) * 1000.0
        let perFrame4 = metal4 / Double(frames) * 1000.0
        let ratio = metal4 / metal3
        let speedup = (1.0 / ratio - 1.0) * 100.0

        print("""

        \(label) — \(frames) frames @ \(Self.renderTargetSize.x)x\(Self.renderTargetSize.y):
          Metal 3: \(String(format: "%7.2f", metal3 * 1000.0)) ms total, \(String(format: "%6.3f", perFrame3)) ms/frame
          Metal 4: \(String(format: "%7.2f", metal4 * 1000.0)) ms total, \(String(format: "%6.3f", perFrame4)) ms/frame
          Ratio  :  \(String(format: "%5.2f", ratio))x  (\(String(format: "%+.1f", speedup))% Metal 4 vs Metal 3)

        """)
    }

    private func runScene(
        device: MTLDevice,
        backend: MetalBackend,
        frames: Int,
        warmup: Int,
        renderingMode: RenderingMode,
        buildScene: (Context) -> SceneBuild
    ) throws -> TimeInterval {
        let activeOutputs: RendererOutputs = renderingMode == .deferredGeometry
            ? [.color, .albedo, .normals, .pbr, .velocity, .emissive]
            : [.color]
        let context = Context(
            device: device,
            backend: backend,
            sampleCount: 1,
            colorPixelFormat: .bgra8Unorm,
            depthPixelFormat: .depth32Float,
            renderingMode: renderingMode,
            activeOutputs: activeOutputs
        )
        guard context.backend == backend else {
            throw XCTSkip("Could not create \(backend) context on this device.")
        }

        let renderer = RenderEncoder(context: context, clearColor: VisualTestHarness.defaultClearColor)
        renderer.resize((width: Float(Self.renderTargetSize.x), height: Float(Self.renderTargetSize.y)))

        let build = buildScene(context)
        let scene = build.scene
        let camera = build.camera

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Self.renderTargetSize.x,
            height: Self.renderTargetSize.y,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private

        let outputTexture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let commandQueue = try XCTUnwrap(device.makeCommandQueue())

        try runFrames(
            count: warmup,
            backend: backend,
            renderer: renderer,
            context: context,
            commandQueue: commandQueue,
            outputTexture: outputTexture,
            scene: scene,
            camera: camera
        )

        let start = CFAbsoluteTimeGetCurrent()
        try runFrames(
            count: frames,
            backend: backend,
            renderer: renderer,
            context: context,
            commandQueue: commandQueue,
            outputTexture: outputTexture,
            scene: scene,
            camera: camera
        )
        return CFAbsoluteTimeGetCurrent() - start
    }

    private func runFrames(
        count: Int,
        backend: MetalBackend,
        renderer: RenderEncoder,
        context: Context,
        commandQueue: MTLCommandQueue,
        outputTexture: MTLTexture,
        scene: Object,
        camera: Camera
    ) throws {
        let viewport = MTLViewport(originX: 0, originY: 0, width: Double(Self.renderTargetSize.x), height: Double(Self.renderTargetSize.y), znear: 0, zfar: 1)
        switch backend {
        case .metal3:
            for _ in 0 ..< count {
                let renderPassDescriptor = MTLRenderPassDescriptor()
                renderPassDescriptor.colorAttachments[0].texture = outputTexture
                renderPassDescriptor.colorAttachments[0].loadAction = .clear
                renderPassDescriptor.colorAttachments[0].storeAction = .store
                let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
                renderer.draw(
                    renderPassDescriptor: renderPassDescriptor,
                    commandBuffer: commandBuffer,
                    scene: scene,
                    camera: camera,
                    viewport: viewport
                )
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                if let error = commandBuffer.error { throw error }
            }
        case .metal4:
            if #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) {
                guard let support = context.metal4Support else {
                    throw XCTSkip("Metal 4 support not available.")
                }
                let frameDone = DispatchSemaphore(value: 0)
                for frameIndex in 0 ..< count {
                    let renderPassDescriptor = MTLRenderPassDescriptor()
                    renderPassDescriptor.colorAttachments[0].texture = outputTexture
                    renderPassDescriptor.colorAttachments[0].loadAction = .clear
                    renderPassDescriptor.colorAttachments[0].storeAction = .store
                    let frameCommand = try XCTUnwrap(support.makeFrameCommand(frameIndex: frameIndex))
                    let didDraw = renderer.draw(
                        renderPassDescriptor: renderPassDescriptor,
                        frameCommand: frameCommand,
                        scene: scene,
                        cameras: [camera],
                        viewports: [viewport]
                    )
                    XCTAssertTrue(didDraw, "Metal 4 draw failed: \(renderer.lastFrameCommandDrawFailure ?? "unknown")")

                    frameCommand.commit { frameDone.signal() }
                    frameDone.wait()
                }
            }
        }
    }

    // MARK: - Scene builders

    private func makeForwardScene(meshCount: Int, withShadows: Bool) -> (Context) -> SceneBuild {
        return { context in
            let scene = Object(context: context, label: "Perf Forward Scene")

            let light = DirectionalLight(context: context, color: [1, 1, 1], intensity: 1.4)
            light.position = [3, 5, 4]
            light.lookAt(target: .zero)
            light.castShadow = withShadows
            if withShadows, let shadowCamera = light.shadow.camera as? OrthographicCamera {
                shadowCamera.update(left: -5, right: 5, bottom: -5, top: 5)
                light.shadow.resolution = (1024, 1024)
            }
            scene.add(light)

            // Casts shadows + receives them — adds shadow caster + receiver to the perf load.
            let floor = Mesh(
                context: context,
                label: "Floor",
                geometry: PlaneGeometry(context: context, size: 16, orientation: .zx),
                material: BasicDiffuseMaterial(context: context, color: [0.7, 0.7, 0.75, 1.0], blending: .disabled, hardness: 0.6)
            )
            floor.position.y = -1.5
            floor.receiveShadow = withShadows
            scene.add(floor)

            let sharedGeometry = SphereGeometry(context: context, radius: 0.18, angularResolution: 16, verticalResolution: 8)
            let sharedMaterial = BasicDiffuseMaterial(context: context, color: [0.92, 0.74, 0.24, 1.0], blending: .disabled, hardness: 0.65)
            let side = Int(Double(meshCount).squareRoot().rounded(.up))
            for i in 0 ..< meshCount {
                let x = i % side
                let y = i / side
                let mesh = Mesh(context: context, geometry: sharedGeometry, material: sharedMaterial.clone())
                let stride: Float = 4.0 / Float(side)
                mesh.position = [Float(x) * stride - 2.0, Float(y) * stride - 2.0, 0]
                if withShadows {
                    mesh.castShadow = true
                    mesh.receiveShadow = true
                }
                scene.add(mesh)
            }

            let camera = PerspectiveCamera(context: context, position: [0, 1, 7], near: 0.1, far: 100.0, fov: 30.0)
            camera.aspect = Float(Self.renderTargetSize.x) / Float(Self.renderTargetSize.y)
            camera.lookAt(target: .zero)
            return SceneBuild(scene: scene, camera: camera)
        }
    }

    private func makeDeferredScene(meshCount: Int) -> (Context) -> SceneBuild {
        return { context in
            let scene = Object(context: context, label: "Perf Deferred Scene")

            let light = DirectionalLight(context: context, color: [1, 1, 1], intensity: 1.4)
            light.position = [3, 5, 4]
            light.lookAt(target: .zero)
            scene.add(light)

            let floor = Mesh(
                context: context,
                label: "Floor",
                geometry: PlaneGeometry(context: context, size: 16, orientation: .zx),
                material: StandardMaterial(context: context, baseColor: [0.7, 0.7, 0.75, 1.0], metallic: 0.0, roughness: 0.9)
            )
            floor.position.y = -1.5
            scene.add(floor)

            let sharedGeometry = SphereGeometry(context: context, radius: 0.18, angularResolution: 16, verticalResolution: 8)
            let sharedMaterial = StandardMaterial(
                context: context,
                baseColor: [0.92, 0.28, 0.18, 1.0],
                metallic: 0.7,
                roughness: 0.3,
                specular: 0.9
            )
            let side = Int(Double(meshCount).squareRoot().rounded(.up))
            for i in 0 ..< meshCount {
                let x = i % side
                let y = i / side
                let mesh = Mesh(context: context, geometry: sharedGeometry, material: sharedMaterial.clone())
                let stride: Float = 4.0 / Float(side)
                mesh.position = [Float(x) * stride - 2.0, Float(y) * stride - 2.0, 0]
                scene.add(mesh)
            }

            let camera = PerspectiveCamera(context: context, position: [0, 1, 7], near: 0.1, far: 100.0, fov: 30.0)
            camera.aspect = Float(Self.renderTargetSize.x) / Float(Self.renderTargetSize.y)
            camera.lookAt(target: .zero)
            return SceneBuild(scene: scene, camera: camera)
        }
    }
}
