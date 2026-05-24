import Metal
@testable import Satin
import XCTest

final class Metal4ArgumentTablesTests: XCTestCase {
    func testMetal4ArgumentTablesBindSupportedSlotsAndRejectUnsupportedSlots() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 argument tables require OS 26 SDK runtime support.")
        }

        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        guard let tables = Metal4ArgumentTables(device: device) else {
            throw XCTSkip("Metal 4 argument tables are not available on this device.")
        }

        let buffer = try XCTUnwrap(device.makeBuffer(length: 256))
        XCTAssertTrue(tables.setVertexBuffer(buffer, offset: 16, index: .Custom10))
        XCTAssertFalse(tables.setVertexBuffer(buffer, offset: 0, index: .Custom11))
        XCTAssertTrue(tables.setFragmentBuffer(buffer, offset: 32, index: .DirectShadowMatrices))

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        let texture = try XCTUnwrap(device.makeTexture(descriptor: textureDescriptor))
        XCTAssertTrue(tables.setVertexTexture(texture, index: .Custom16))
        XCTAssertTrue(tables.setFragmentTexture(texture, index: .DirectShadow0))

        let samplerDescriptor = MTLSamplerDescriptor()
        let samplerState = try XCTUnwrap(device.makeSamplerState(descriptor: samplerDescriptor))
        XCTAssertTrue(tables.setFragmentSamplerState(samplerState, index: .Custom15))
        XCTAssertFalse(tables.setFragmentSamplerState(samplerState, index: .Custom16))
    }
}
