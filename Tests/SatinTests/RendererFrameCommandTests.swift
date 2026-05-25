import Metal
@testable import Satin
import XCTest

final class RendererFrameCommandTests: XCTestCase {
    final class TestRenderer: Renderer {}

    final class FallbackTestRenderer: Renderer {
        var commandBufferDrawCount = 0

        override func draw(texture: MTLTexture, commandBuffer: MTLCommandBuffer) {
            commandBufferDrawCount += 1
        }
    }

    final class BindingProbeTextureComputeSystem: TextureComputeSystem {
        override var prefix: String { "RandomNoise" }

        init(device: MTLDevice, textureDescriptor: MTLTextureDescriptor) {
            super.init(
                device: device,
                pipelinesURL: getPipelinesComputeURL()!,
                textureDescriptors: [textureDescriptor]
            )
        }

        override func bind(_ binding: any ComputeArgumentBinding, iteration: Int) -> Int {
            let index = super.bind(binding, iteration: iteration)
            binding.setTexture(dstTexture, index: index)
            return index + 1
        }
    }

    final class RecordingComputeArgumentBinding: ComputeArgumentBinding {
        let backend: MetalBackend
        var buffers: [(offset: Int, index: Int)] = []
        var textures: [Int] = []

        init(backend: MetalBackend) {
            self.backend = backend
        }

        func setBuffer(_ buffer: MTLBuffer, offset: Int, index: ComputeBufferIndex) -> Bool {
            setBuffer(buffer, offset: offset, index: index.rawValue)
        }

        func setBuffer(_ buffer: MTLBuffer, offset: Int, index: Int) -> Bool {
            buffers.append((offset: offset, index: index))
            return true
        }

        func setTexture(_ texture: MTLTexture?, index: ComputeTextureIndex) -> Bool {
            setTexture(texture, index: index.rawValue)
        }

        func setTexture(_ texture: MTLTexture?, index: Int) -> Bool {
            textures.append(index)
            return texture != nil
        }
    }

    private func makeDevice() -> MTLDevice? {
        MTLCreateSystemDefaultDevice()
    }

    func testDefaultRendererCreatesAndCommitsFrameCommandBuffer() throws {
        let device = try XCTUnwrap(makeDevice())
        let context = Context(device: device, sampleCount: 1, colorPixelFormat: .bgra8Unorm)
        let renderer = TestRenderer(context: context)

        let commandBuffer = try XCTUnwrap(renderer.preDraw())
        XCTAssertEqual(renderer.frameIndex, 0)

        renderer.postDraw(commandBuffer: commandBuffer)
        commandBuffer.waitUntilCompleted()

        XCTAssertEqual(commandBuffer.status, .completed)
    }

    func testRendererCreatesBackendFrameCommand() throws {
        let device = try XCTUnwrap(makeDevice())
        let context = Context(device: device, sampleCount: 1, colorPixelFormat: .bgra8Unorm)
        let renderer = TestRenderer(context: context)

        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? MetalFrameCommand)
        XCTAssertEqual(frameCommand.backend, .metal3)
        XCTAssertEqual(frameCommand.frameIndex, 0)

        renderer.commitFrameCommand(frameCommand)
        frameCommand.commandBuffer.waitUntilCompleted()

        XCTAssertEqual(frameCommand.commandBuffer.status, .completed)
    }

    func testRendererBuildsRenderPassDescriptorForFrameCommandDraw() throws {
        let device = try XCTUnwrap(makeDevice())
        let context = Context(device: device, sampleCount: 1, colorPixelFormat: .bgra8Unorm, depthPixelFormat: .depth32Float)
        let renderer = TestRenderer(context: context)
        renderer.frameIndex = 0
        let texture = try XCTUnwrap(makeTexture(device: device))

        let renderPassDescriptor = renderer.makeRenderPassDescriptor(texture: texture)

        XCTAssertTrue(renderPassDescriptor.colorAttachments[0].texture === texture)
        XCTAssertEqual(renderPassDescriptor.renderTargetWidth, texture.width)
        XCTAssertEqual(renderPassDescriptor.renderTargetHeight, texture.height)
        XCTAssertNotNil(renderPassDescriptor.depthAttachment.texture)
        XCTAssertEqual(renderPassDescriptor.stencilAttachment.loadAction, .clear)
    }

    func testRenderEncoderDrawsWithBackendFrameCommand() throws {
        let device = try XCTUnwrap(makeDevice())
        let context = Context(device: device, sampleCount: 1, colorPixelFormat: .bgra8Unorm)
        let renderer = TestRenderer(context: context)
        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? MetalFrameCommand)
        let renderEncoder = RenderEncoder(context: context)
        let scene = Object(context: context)
        let camera = PerspectiveCamera(context: context, position: [0.0, 0.0, 4.0], near: 0.1, far: 100.0, fov: 30.0)
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = try XCTUnwrap(makeTexture(device: device))
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        XCTAssertTrue(renderEncoder.draw(
            renderPassDescriptor: renderPassDescriptor,
            frameCommand: frameCommand,
            scene: scene,
            camera: camera,
            viewport: MTLViewport(originX: 0, originY: 0, width: 4, height: 4, znear: 0, zfar: 1)
        ))
        XCTAssertNil(renderEncoder.lastFrameCommandDrawFailure)

        renderer.commitFrameCommand(frameCommand)
        frameCommand.commandBuffer.waitUntilCompleted()

        XCTAssertEqual(frameCommand.commandBuffer.status, .completed)
    }

    func testMetal4FrameCommandDrawSupportsMultisample() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }

        let device = try XCTUnwrap(makeDevice())
        let context = Context(device: device, backend: .metal4, sampleCount: 4, colorPixelFormat: .bgra8Unorm)
        guard context.backend == .metal4 else {
            throw XCTSkip("Metal 4 command queues are not available on this device.")
        }

        let renderer = TestRenderer(context: context)
        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? Metal4FrameCommand)
        let renderEncoder = RenderEncoder(context: context)
        let scene = Object(context: context)
        let camera = PerspectiveCamera(context: context, position: [0.0, 0.0, 4.0], near: 0.1, far: 100.0, fov: 30.0)
        let renderPassDescriptor = renderer.makeRenderPassDescriptor(texture: try XCTUnwrap(makeTexture(device: device)))

        XCTAssertTrue(renderEncoder.draw(
            renderPassDescriptor: renderPassDescriptor,
            frameCommand: frameCommand,
            scene: scene,
            camera: camera,
            viewport: MTLViewport(originX: 0, originY: 0, width: 4, height: 4, znear: 0, zfar: 1)
        ))
        XCTAssertNil(renderEncoder.lastFrameCommandDrawFailure)
        XCTAssertEqual(renderPassDescriptor.colorAttachments[0].storeAction, .storeAndMultisampleResolve)
        XCTAssertNotNil(renderPassDescriptor.colorAttachments[0].resolveTexture)

        renderer.commitFrameCommand(frameCommand)
    }

    func testRendererBuildsFallbackCommandBufferForFailedMetal4Draw() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }

        let device = try XCTUnwrap(makeDevice())
        let context = Context(device: device, backend: .metal4, sampleCount: 1, colorPixelFormat: .bgra8Unorm)
        guard context.backend == .metal4 else {
            throw XCTSkip("Metal 4 command queues are not available on this device.")
        }

        let renderer = FallbackTestRenderer(context: context)
        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? Metal4FrameCommand)
        let fallbackCommandBuffer = try XCTUnwrap(renderer.makeFallbackCommandBuffer(
            texture: try XCTUnwrap(makeTexture(device: device)),
            failedFrameCommand: frameCommand
        ))

        XCTAssertEqual(renderer.commandBufferDrawCount, 1)

        renderer.commitFrameCommand(frameCommand)
        fallbackCommandBuffer.commit()
        fallbackCommandBuffer.waitUntilCompleted()

        XCTAssertEqual(fallbackCommandBuffer.status, .completed)
    }

    func testMetal4FrameCommandDrawSupportsVertexAmplification() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }

        let device = try XCTUnwrap(makeDevice())
        let context = Context(
            device: device,
            backend: .metal4,
            sampleCount: 1,
            colorPixelFormat: .bgra8Unorm,
            vertexAmplificationCount: 2
        )
        guard context.backend == .metal4 else {
            throw XCTSkip("Metal 4 command queues are not available on this device.")
        }

        let renderer = TestRenderer(context: context)
        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? Metal4FrameCommand)
        let renderEncoder = RenderEncoder(context: context)
        let scene = Object(context: context)
        let cameras = [
            PerspectiveCamera(context: context, position: [0.0, 0.0, 4.0], near: 0.1, far: 100.0, fov: 30.0),
            PerspectiveCamera(context: context, position: [0.0, 0.0, 4.0], near: 0.1, far: 100.0, fov: 30.0)
        ]
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = try XCTUnwrap(makeArrayTexture(device: device, arrayLength: 2))
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.renderTargetArrayLength = 2
        renderPassDescriptor.renderTargetWidth = 4
        renderPassDescriptor.renderTargetHeight = 4

        XCTAssertTrue(renderEncoder.draw(
            renderPassDescriptor: renderPassDescriptor,
            frameCommand: frameCommand,
            scene: scene,
            cameras: cameras,
            viewports: [
                MTLViewport(originX: 0, originY: 0, width: 4, height: 4, znear: 0, zfar: 1),
                MTLViewport(originX: 0, originY: 0, width: 4, height: 4, znear: 0, zfar: 1)
            ]
        ))
        XCTAssertNil(renderEncoder.lastFrameCommandDrawFailure)

        renderer.commitFrameCommand(frameCommand)
    }

    func testMetal4FrameCommandDrawSupportsCustomVertexAmplificationViewMappings() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }

        let device = try XCTUnwrap(makeDevice())
        let context = Context(
            device: device,
            backend: .metal4,
            sampleCount: 1,
            colorPixelFormat: .bgra8Unorm,
            vertexAmplificationCount: 2
        )
        guard context.backend == .metal4 else {
            throw XCTSkip("Metal 4 command queues are not available on this device.")
        }

        let renderer = TestRenderer(context: context)
        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? Metal4FrameCommand)
        let renderEncoder = RenderEncoder(context: context)
        let scene = Object(context: context)
        let cameras = [
            PerspectiveCamera(context: context, position: [0.0, 0.0, 4.0], near: 0.1, far: 100.0, fov: 30.0),
            PerspectiveCamera(context: context, position: [0.0, 0.0, 4.0], near: 0.1, far: 100.0, fov: 30.0)
        ]
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = try XCTUnwrap(makeArrayTexture(device: device, arrayLength: 2))
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.renderTargetArrayLength = 2
        renderPassDescriptor.renderTargetWidth = 4
        renderPassDescriptor.renderTargetHeight = 4

        let viewMappings = [
            MTLVertexAmplificationViewMapping(viewportArrayIndexOffset: 0, renderTargetArrayIndexOffset: 0),
            MTLVertexAmplificationViewMapping(viewportArrayIndexOffset: 1, renderTargetArrayIndexOffset: 1)
        ]

        XCTAssertTrue(renderEncoder.draw(
            renderPassDescriptor: renderPassDescriptor,
            frameCommand: frameCommand,
            scene: scene,
            cameras: cameras,
            viewports: [
                MTLViewport(originX: 0, originY: 0, width: 4, height: 4, znear: 0, zfar: 1),
                MTLViewport(originX: 0, originY: 0, width: 4, height: 4, znear: 0, zfar: 1)
            ],
            viewMappings: viewMappings
        ))
        XCTAssertNil(renderEncoder.lastFrameCommandDrawFailure)

        renderer.commitFrameCommand(frameCommand)
    }

    func testMetal4FrameCommandDrawSupportsAlphaOit() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }

        let device = try XCTUnwrap(makeDevice())
        let context = Context(
            device: device,
            backend: .metal4,
            sampleCount: 1,
            colorPixelFormat: .bgra8Unorm,
            depthPixelFormat: .depth32Float,
            alphaOitEnabled: true
        )
        guard context.backend == .metal4 else {
            throw XCTSkip("Metal 4 command queues are not available on this device.")
        }

        let renderer = TestRenderer(context: context)
        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? Metal4FrameCommand)
        let renderEncoder = RenderEncoder(context: context)
        let scene = Object(context: context)
        let material = BasicColorMaterial(
            context: context,
            color: simd_float4(1.0, 0.2, 0.1, 0.5),
            blending: .alpha
        )
        let mesh = Mesh(
            context: context,
            geometry: PlaneGeometry(context: context, width: 1.0, height: 1.0),
            material: material
        )
        scene.add(mesh)

        XCTAssertTrue(renderEncoder.draw(
            renderPassDescriptor: renderer.makeRenderPassDescriptor(texture: try XCTUnwrap(makeTexture(device: device))),
            frameCommand: frameCommand,
            scene: scene,
            camera: PerspectiveCamera(context: context, position: [0.0, 0.0, 4.0], near: 0.1, far: 100.0, fov: 30.0),
            viewport: MTLViewport(originX: 0, originY: 0, width: 4, height: 4, znear: 0, zfar: 1)
        ))
        XCTAssertNil(renderEncoder.lastFrameCommandDrawFailure)

        renderer.commitFrameCommand(frameCommand)
    }

    func testMetal4FrameCommandDrawSupportsDirectionalShadows() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }

        let device = try XCTUnwrap(makeDevice())
        let context = Context(
            device: device,
            backend: .metal4,
            sampleCount: 1,
            colorPixelFormat: .bgra8Unorm,
            depthPixelFormat: .depth32Float
        )
        guard context.backend == .metal4 else {
            throw XCTSkip("Metal 4 command queues are not available on this device.")
        }

        let renderer = TestRenderer(context: context)
        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? Metal4FrameCommand)
        let renderEncoder = RenderEncoder(context: context)
        let scene = Object(context: context)

        let light = DirectionalLight(context: context, color: simd_float3(repeating: 1.0), intensity: 1.0)
        light.position = [2.0, 3.0, 2.0]
        light.lookAt(target: .zero, up: Satin.worldUpDirection)
        light.castShadow = true
        light.shadow.resolution = (width: 4, height: 4)

        let receiver = Mesh(
            context: context,
            geometry: PlaneGeometry(context: context, size: 2.0, orientation: .zx),
            material: BasicDiffuseMaterial(context: context, color: simd_float4(0.35, 0.35, 0.4, 1.0))
        )
        receiver.receiveShadow = true

        let caster = Mesh(
            context: context,
            geometry: PlaneGeometry(context: context, width: 0.5, height: 0.5),
            material: BasicDiffuseMaterial(context: context, color: simd_float4(0.9, 0.2, 0.1, 1.0))
        )
        caster.position.y = 0.5
        caster.castShadow = true

        scene.add(light)
        scene.add(receiver)
        scene.add(caster)

        XCTAssertTrue(renderEncoder.draw(
            renderPassDescriptor: renderer.makeRenderPassDescriptor(texture: try XCTUnwrap(makeTexture(device: device))),
            frameCommand: frameCommand,
            scene: scene,
            camera: PerspectiveCamera(context: context, position: [0.0, 0.75, 4.0], near: 0.1, far: 100.0, fov: 30.0),
            viewport: MTLViewport(originX: 0, originY: 0, width: 4, height: 4, znear: 0, zfar: 1)
        ))
        XCTAssertNil(renderEncoder.lastFrameCommandDrawFailure)

        renderer.commitFrameCommand(frameCommand)
    }

    func testMetal4FrameCommandDrawSupportsForwardPlusOutputs() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }

        let device = try XCTUnwrap(makeDevice())
        let context = Context(
            device: device,
            backend: .metal4,
            sampleCount: 1,
            colorPixelFormat: .bgra8Unorm,
            depthPixelFormat: .depth32Float,
            renderingMode: .forwardPlus,
            activeOutputs: [.color, .normals]
        )
        guard context.backend == .metal4 else {
            throw XCTSkip("Metal 4 command queues are not available on this device.")
        }

        let renderer = TestRenderer(context: context)
        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? Metal4FrameCommand)
        let renderEncoder = RenderEncoder(context: context)
        renderEncoder.resize((width: 4, height: 4))
        let scene = Object(context: context)
        let mesh = Mesh(
            context: context,
            geometry: PlaneGeometry(context: context, width: 1.0, height: 1.0),
            material: BasicDiffuseMaterial(context: context, color: simd_float4(0.2, 0.6, 1.0, 1.0))
        )
        scene.add(mesh)

        XCTAssertTrue(renderEncoder.draw(
            renderPassDescriptor: renderer.makeRenderPassDescriptor(texture: try XCTUnwrap(makeTexture(device: device))),
            frameCommand: frameCommand,
            scene: scene,
            camera: PerspectiveCamera(context: context, position: [0.0, 0.0, 4.0], near: 0.1, far: 100.0, fov: 30.0),
            viewport: MTLViewport(originX: 0, originY: 0, width: 4, height: 4, znear: 0, zfar: 1)
        ))
        XCTAssertNil(renderEncoder.lastFrameCommandDrawFailure)
        XCTAssertNotNil(renderEncoder.normalTexture)

        renderer.commitFrameCommand(frameCommand)
    }

    func testMetal4FrameCommandDrawSupportsDeferredGeometry() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }

        let device = try XCTUnwrap(makeDevice())
        let context = Context(
            device: device,
            backend: .metal4,
            sampleCount: 1,
            colorPixelFormat: .bgra8Unorm,
            depthPixelFormat: .depth32Float,
            renderingMode: .deferredGeometry
        )
        guard context.backend == .metal4 else {
            throw XCTSkip("Metal 4 command queues are not available on this device.")
        }

        let renderer = TestRenderer(context: context)
        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? Metal4FrameCommand)
        let renderEncoder = RenderEncoder(context: context)
        renderEncoder.resize((width: 4, height: 4))

        let scene = Object(context: context)
        let light = DirectionalLight(context: context, color: simd_float3(repeating: 1.0), intensity: 1.0)
        let mesh = Mesh(
            context: context,
            geometry: PlaneGeometry(context: context, width: 1.0, height: 1.0),
            material: BasicDiffuseMaterial(context: context, color: simd_float4(0.2, 0.6, 1.0, 1.0))
        )
        scene.add(light)
        scene.add(mesh)

        XCTAssertTrue(renderEncoder.draw(
            renderPassDescriptor: renderer.makeRenderPassDescriptor(texture: try XCTUnwrap(makeTexture(device: device))),
            frameCommand: frameCommand,
            scene: scene,
            camera: PerspectiveCamera(context: context, position: [0.0, 0.0, 4.0], near: 0.1, far: 100.0, fov: 30.0),
            viewport: MTLViewport(originX: 0, originY: 0, width: 4, height: 4, znear: 0, zfar: 1)
        ))
        XCTAssertNil(renderEncoder.lastFrameCommandDrawFailure)
        XCTAssertNotNil(renderEncoder.albedoTexture)
        XCTAssertNotNil(renderEncoder.normalTexture)
        XCTAssertNotNil(renderEncoder.pbrTexture)
        XCTAssertNotNil(renderEncoder.emissiveTexture)

        renderer.commitFrameCommand(frameCommand)
    }

    func testMetal4FrameCommandDrawSupportsPostProcessEncoder() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }

        let device = try XCTUnwrap(makeDevice())
        let context = Context(
            device: device,
            backend: .metal4,
            sampleCount: 1,
            colorPixelFormat: .bgra8Unorm,
            depthPixelFormat: .depth32Float
        )
        guard context.backend == .metal4 else {
            throw XCTSkip("Metal 4 command queues are not available on this device.")
        }

        let renderer = TestRenderer(context: context)
        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? Metal4FrameCommand)
        let postProcessor = PostProcessEncoder(
            context: context,
            material: BasicColorMaterial(context: context, color: simd_float4(0.1, 0.2, 0.3, 1.0))
        )
        postProcessor.resize(size: (width: 4, height: 4), scaleFactor: 1.0)

        XCTAssertTrue(postProcessor.draw(
            renderPassDescriptor: renderer.makeRenderPassDescriptor(texture: try XCTUnwrap(makeTexture(device: device))),
            frameCommand: frameCommand,
            renderTarget: try XCTUnwrap(makeTexture(device: device))
        ))
        XCTAssertNil(postProcessor.renderer.lastFrameCommandDrawFailure)

        renderer.commitFrameCommand(frameCommand)
    }

    func testMetal4FrameCommandSupportsRandomNoiseGenerator() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }

        let device = try XCTUnwrap(makeDevice())
        let context = Context(device: device, backend: .metal4, sampleCount: 1, colorPixelFormat: .bgra8Unorm)
        guard context.backend == .metal4 else {
            throw XCTSkip("Metal 4 command queues are not available on this device.")
        }

        let renderer = TestRenderer(context: context)
        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? Metal4FrameCommand)
        let generator = RandomNoiseGenerator(device: device, size: (width: 4, height: 4), range: 0.0 ... 1.0, seed: 42)
        let texture = try XCTUnwrap(generator.encode(frameCommand: frameCommand))

        XCTAssertEqual(texture.width, 4)
        XCTAssertEqual(texture.height, 4)

        renderer.commitFrameCommand(frameCommand)
    }

    func testTextureComputeSystemExposesPublicArgumentBindingOverride() throws {
        let device = try XCTUnwrap(makeDevice())
        let compute = BindingProbeTextureComputeSystem(
            device: device,
            textureDescriptor: makeComputeTextureDescriptor(pixelFormat: .rgba32Float)
        )
        let binding = RecordingComputeArgumentBinding(backend: .metal4)

        XCTAssertEqual(compute.bind(binding, iteration: 0), ComputeTextureIndex.Custom0.rawValue + 2)
        XCTAssertEqual(binding.backend, .metal4)
        XCTAssertEqual(binding.textures, [ComputeTextureIndex.Custom0.rawValue, ComputeTextureIndex.Custom0.rawValue + 1])
    }

    func testMetal4FrameCommandSupportsBrdfGenerator() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }

        let device = try XCTUnwrap(makeDevice())
        let context = Context(device: device, backend: .metal4, sampleCount: 1, colorPixelFormat: .bgra8Unorm)
        guard context.backend == .metal4 else {
            throw XCTSkip("Metal 4 command queues are not available on this device.")
        }

        let renderer = TestRenderer(context: context)
        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? Metal4FrameCommand)
        let generator = BrdfGenerator(device: device, size: 4)
        let texture = try XCTUnwrap(generator.encode(frameCommand: frameCommand))

        XCTAssertEqual(texture.width, 4)
        XCTAssertEqual(texture.height, 4)

        renderer.commitFrameCommand(frameCommand)
    }

    func testMetal4FrameCommandSupportsYcbcrConverter() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }

        let device = try XCTUnwrap(makeDevice())
        let context = Context(device: device, backend: .metal4, sampleCount: 1, colorPixelFormat: .bgra8Unorm)
        guard context.backend == .metal4 else {
            throw XCTSkip("Metal 4 command queues are not available on this device.")
        }

        let renderer = TestRenderer(context: context)
        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? Metal4FrameCommand)
        let converter = YCbCrToRGBConverter(device: device, width: 4, height: 4)
        let texture = try XCTUnwrap(converter.encode(
            frameCommand: frameCommand,
            yTexture: try XCTUnwrap(makeComputeTexture(device: device, pixelFormat: .r32Float)),
            cbcrTexture: try XCTUnwrap(makeComputeTexture(device: device, pixelFormat: .rg32Float))
        ))

        XCTAssertEqual(texture.width, 4)
        XCTAssertEqual(texture.height, 4)

        renderer.commitFrameCommand(frameCommand)
    }

    func testMetal4FrameCommandSupportsDiffuseIblGenerator() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }

        let device = try XCTUnwrap(makeDevice())
        let context = Context(device: device, backend: .metal4, sampleCount: 1, colorPixelFormat: .bgra8Unorm)
        guard context.backend == .metal4 else {
            throw XCTSkip("Metal 4 command queues are not available on this device.")
        }

        let renderer = TestRenderer(context: context)
        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? Metal4FrameCommand)
        let generator = DiffuseIBLGenerator(device: device)
        let destinationTexture = try XCTUnwrap(makeCubeTexture(device: device, mipmapped: false))

        generator.encode(
            frameCommand: frameCommand,
            sourceTexture: try XCTUnwrap(makeCubeTexture(device: device, mipmapped: false)),
            destinationTexture: destinationTexture
        )

        XCTAssertEqual(destinationTexture.width, 4)
        XCTAssertEqual(destinationTexture.height, 4)

        renderer.commitFrameCommand(frameCommand)
    }

    func testMetal4FrameCommandSupportsSpecularIblGenerator() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }

        let device = try XCTUnwrap(makeDevice())
        let context = Context(device: device, backend: .metal4, sampleCount: 1, colorPixelFormat: .bgra8Unorm)
        guard context.backend == .metal4 else {
            throw XCTSkip("Metal 4 command queues are not available on this device.")
        }

        let renderer = TestRenderer(context: context)
        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? Metal4FrameCommand)
        let generator = SpecularIBLGenerator(device: device)
        let destinationTexture = try XCTUnwrap(makeCubeTexture(device: device, mipmapped: true))

        generator.encode(
            frameCommand: frameCommand,
            sourceTexture: try XCTUnwrap(makeCubeTexture(device: device, mipmapped: true)),
            destinationTexture: destinationTexture
        )

        XCTAssertEqual(destinationTexture.width, 4)
        XCTAssertEqual(destinationTexture.height, 4)

        renderer.commitFrameCommand(frameCommand)
    }

    func testMetal4FrameCommandSupportsCubemapGenerator() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }

        let device = try XCTUnwrap(makeDevice())
        let context = Context(device: device, backend: .metal4, sampleCount: 1, colorPixelFormat: .bgra8Unorm)
        guard context.backend == .metal4 else {
            throw XCTSkip("Metal 4 command queues are not available on this device.")
        }

        let renderer = TestRenderer(context: context)
        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? Metal4FrameCommand)
        let generator = CubemapGenerator(device: device)
        let destinationTexture = try XCTUnwrap(makeCubeTexture(device: device, mipmapped: true))

        XCTAssertTrue(generator.encode(
            frameCommand: frameCommand,
            sourceTexture: try XCTUnwrap(makeCubeTexture(device: device, mipmapped: true)),
            destinationTexture: destinationTexture
        ))
        XCTAssertEqual(destinationTexture.mipmapLevelCount, 3)

        renderer.commitFrameCommand(frameCommand)
    }

    func testMetal4FrameCommandSupportsExtendedPostProcessors() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }

        let device = try XCTUnwrap(makeDevice())
        let context = Context(device: device, backend: .metal4, sampleCount: 1, colorPixelFormat: .bgra8Unorm)
        guard context.backend == .metal4 else {
            throw XCTSkip("Metal 4 command queues are not available on this device.")
        }

        let renderer = TestRenderer(context: context)
        let frameCommand = try XCTUnwrap(renderer.makeFrameCommand() as? Metal4FrameCommand)
        let outputRenderPassDescriptor = renderer.makeRenderPassDescriptor(texture: try XCTUnwrap(makeTexture(device: device)))
        let colorTexture = try XCTUnwrap(makeShaderTexture(device: device, pixelFormat: .bgra8Unorm))

        let ssao = SsaoPostProcessEncoder(context: context)
        ssao.resize(size: (width: 4, height: 4), scaleFactor: 1.0)
        ssao.colorTexture = colorTexture
        XCTAssertTrue(ssao.draw(renderPassDescriptor: outputRenderPassDescriptor, frameCommand: frameCommand))

        let ssgi = SsgiPostProcessEncoder(context: context)
        ssgi.resize(size: (width: 4, height: 4), scaleFactor: 1.0)
        ssgi.colorTexture = colorTexture
        XCTAssertTrue(ssgi.draw(renderPassDescriptor: outputRenderPassDescriptor, frameCommand: frameCommand))

        let motionBlur = MotionBlurPostProcessEncoder(context: context)
        motionBlur.resize(size: (width: 4, height: 4), scaleFactor: 1.0)
        motionBlur.colorTexture = colorTexture
        motionBlur.velocityTexture = try XCTUnwrap(makeShaderTexture(device: device, pixelFormat: .rg16Float))
        XCTAssertTrue(motionBlur.draw(renderPassDescriptor: outputRenderPassDescriptor, frameCommand: frameCommand))

        let bokeh = BokehDepthOfFieldPostProcessEncoder(context: context)
        bokeh.resize(size: (width: 4, height: 4), scaleFactor: 1.0)
        XCTAssertTrue(bokeh.draw(renderPassDescriptor: outputRenderPassDescriptor, frameCommand: frameCommand))

        renderer.commitFrameCommand(frameCommand)
    }

    private func makeTexture(device: MTLDevice) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 4,
            height: 4,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget]
        return device.makeTexture(descriptor: descriptor)
    }

    private func makeComputeTexture(device: MTLDevice, pixelFormat: MTLPixelFormat) -> MTLTexture? {
        device.makeTexture(descriptor: makeComputeTextureDescriptor(pixelFormat: pixelFormat))
    }

    private func makeComputeTextureDescriptor(pixelFormat: MTLPixelFormat) -> MTLTextureDescriptor {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: 4,
            height: 4,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        return descriptor
    }

    private func makeShaderTexture(device: MTLDevice, pixelFormat: MTLPixelFormat) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: 4,
            height: 4,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        return device.makeTexture(descriptor: descriptor)
    }

    private func makeCubeTexture(device: MTLDevice, mipmapped: Bool) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.textureCubeDescriptor(
            pixelFormat: .rgba16Float,
            size: 4,
            mipmapped: mipmapped
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        return device.makeTexture(descriptor: descriptor)
    }

    private func makeArrayTexture(device: MTLDevice, arrayLength: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = .bgra8Unorm
        descriptor.width = 4
        descriptor.height = 4
        descriptor.arrayLength = arrayLength
        descriptor.textureType = .type2DArray
        descriptor.usage = [.renderTarget]
        return device.makeTexture(descriptor: descriptor)
    }
}
