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

    func testMetal3CommandBufferHelperReflectsBackend() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let queue = try XCTUnwrap(device.makeCommandQueue())
        let commandBuffer = try XCTUnwrap(queue.makeCommandBuffer())

        // Metal 3 frame command exposes its classic buffer; the MPS-only encoders rely on this.
        let metal3: any SatinFrameCommand = MetalFrameCommand(frameIndex: 0, commandBuffer: commandBuffer)
        XCTAssertTrue(metal3.metal3CommandBuffer === commandBuffer)

        // Metal 4 frame command has no classic buffer, so MPS-only paths skip/fall back cleanly.
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *),
              device.supportsFamily(.metal4),
              let support = Metal4Support(device: device, maxBuffersInFlight: 1),
              let metal4 = support.makeFrameCommand(frameIndex: 0)
        else { return }
        XCTAssertNil(metal4.metal3CommandBuffer)
        metal4.end()
    }

    func testFragmentShadowTextureRangeBindsWithoutFallback() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 render command encoder support requires OS 26 SDK runtime support.")
        }

        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        guard let support = Metal4Support(device: device, maxBuffersInFlight: 1),
              let frameCommand = support.makeFrameCommand(frameIndex: 0)
        else {
            throw XCTSkip("Metal 4 is not available on this device.")
        }

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

        // Two directional shadows' worth of textures, bound contiguously from DirectShadow0.
        // These land at indices ≥42 — before the table was resized this failed the encoder's
        // enum check and tripped the whole-frame Metal 3 fallback.
        let textures = Array<MTLTexture?>(repeating: texture, count: 2 * 6)
        let start = FragmentTextureIndex.DirectShadow0.rawValue
        XCTAssertTrue(encoder.setFragmentTextures(textures, range: start ..< (start + textures.count)))
        XCTAssertNil(encoder.lastBindingFailure)

        renderCommand.renderEncoder.endEncoding()
        frameCommand.end()
    }
}
