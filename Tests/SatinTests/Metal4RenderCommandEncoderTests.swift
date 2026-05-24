import Metal
@testable import Satin
import XCTest

final class Metal4RenderCommandEncoderTests: XCTestCase {
    func testMetal4RenderCommandEncoderComputesIndexedBufferLengthFromOffset() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 render command encoder support requires OS 26 SDK runtime support.")
        }

        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let indexBuffer = try XCTUnwrap(device.makeBuffer(length: 64))

        XCTAssertEqual(Metal4RenderCommandEncoder.indexBufferLength(indexBuffer: indexBuffer, offset: 0), 64)
        XCTAssertEqual(Metal4RenderCommandEncoder.indexBufferLength(indexBuffer: indexBuffer, offset: 16), 48)
        XCTAssertEqual(Metal4RenderCommandEncoder.indexBufferLength(indexBuffer: indexBuffer, offset: 64), 0)
        XCTAssertEqual(Metal4RenderCommandEncoder.indexBufferLength(indexBuffer: indexBuffer, offset: 80), 0)
    }
}
