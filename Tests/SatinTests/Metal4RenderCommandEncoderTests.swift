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

    func testMetal4RenderCommandEncoderReportsFragmentTextureRangeOverflow() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 render command encoder support requires OS 26 SDK runtime support.")
        }

        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let support = try XCTUnwrap(Metal4Support(device: device, maxBuffersInFlight: 1))
        let frameCommand = try XCTUnwrap(support.makeFrameCommand(frameIndex: 0))
        let renderPassDescriptor = MTLRenderPassDescriptor()
        let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        colorDescriptor.usage = [.renderTarget]
        renderPassDescriptor.colorAttachments[0].texture = try XCTUnwrap(device.makeTexture(descriptor: colorDescriptor))
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        let renderCommand = try XCTUnwrap(support.makeRenderCommand(renderPassDescriptor: renderPassDescriptor))
        let argumentTables = try XCTUnwrap(Metal4ArgumentTables(device: device))
        let encoder = Metal4RenderCommandEncoder(renderEncoder: renderCommand.renderEncoder, argumentTables: argumentTables)
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        let texture = try XCTUnwrap(device.makeTexture(descriptor: textureDescriptor))

        XCTAssertFalse(encoder.setFragmentTextures([texture], range: 0 ..< 0))
        XCTAssertEqual(encoder.lastBindingFailure, "Metal 4 fragment texture range 0..<0 cannot bind 1 textures.")

        renderCommand.renderEncoder.endEncoding()
        frameCommand.end()
    }
}
