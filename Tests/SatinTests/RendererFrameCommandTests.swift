import Metal
import Satin
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
}
