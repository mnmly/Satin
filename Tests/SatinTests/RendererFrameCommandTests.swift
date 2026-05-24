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
}
