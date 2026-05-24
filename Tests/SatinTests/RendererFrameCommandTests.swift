import Metal
@testable import Satin
import XCTest

final class RendererFrameCommandTests: XCTestCase {
    final class TestRenderer: Renderer {}

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

        renderer.commitFrameCommand(frameCommand)
        frameCommand.commandBuffer.waitUntilCompleted()

        XCTAssertEqual(frameCommand.commandBuffer.status, .completed)
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
}
