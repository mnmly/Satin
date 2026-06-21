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

    func testFragmentTexturesBindAcrossFullDirectShadowRange() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 argument tables require OS 26 SDK runtime support.")
        }

        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        guard let tables = Metal4ArgumentTables(device: device) else {
            throw XCTSkip("Metal 4 argument tables are not available on this device.")
        }

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        let texture = try XCTUnwrap(device.makeTexture(descriptor: textureDescriptor))

        // Every directional-shadow slot must bind, including indices past 63 that the old
        // 42-slot table and single-UInt64 dirty mask could not represent.
        let firstShadow = FragmentTextureIndex.DirectShadow0.rawValue
        let lastShadow = firstShadow + maxShadowTextures - 1
        for index in firstShadow ... lastShadow {
            XCTAssertTrue(
                tables.setFragmentTexture(texture, index: index),
                "expected bind at fragment texture index \(index)"
            )
        }

        // One past the table capacity fails cleanly (returns false, no crash) so it trips the
        // Metal 3 fallback rather than a Metal range-validation error.
        XCTAssertFalse(tables.setFragmentTexture(texture, index: Metal4ArgumentBindingLayout.maxFragmentTextureBindCount))
    }

    func testMetal4ArgumentTablesReportBoundResourcesForResidency() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 argument tables require OS 26 SDK runtime support.")
        }

        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        var resources = [MTLResource]()
        guard let tables = Metal4ArgumentTables(device: device, resourceHandler: { resources.append($0) }) else {
            throw XCTSkip("Metal 4 argument tables are not available on this device.")
        }

        let buffer = try XCTUnwrap(device.makeBuffer(length: 256))
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        let texture = try XCTUnwrap(device.makeTexture(descriptor: textureDescriptor))

        XCTAssertTrue(tables.setVertexBuffer(buffer, offset: 0, index: .Custom10))
        XCTAssertTrue(tables.setFragmentBuffer(buffer, offset: 0, index: .Custom0))
        XCTAssertTrue(tables.setVertexTexture(texture, index: .Custom0))
        XCTAssertTrue(tables.setFragmentTexture(texture, index: .Custom0))

        XCTAssertEqual(resources.count, 4)
        XCTAssertTrue(resources[0] === buffer)
        XCTAssertTrue(resources[1] === buffer)
        XCTAssertTrue(resources[2] === texture)
        XCTAssertTrue(resources[3] === texture)
    }

    func testMetal4ArgumentTablePoolReusesTablesAfterFrameSlotReset() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 argument table pools require OS 26 SDK runtime support.")
        }

        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let buffer = try XCTUnwrap(device.makeBuffer(length: 256))
        let pool = Metal4ArgumentTablePool(device: device, frameSlotCount: 1)

        var firstResources = [MTLResource]()
        let firstTables = try XCTUnwrap(pool.makeRenderArgumentTables(frameSlot: 0) { firstResources.append($0) })
        let secondTables = try XCTUnwrap(pool.makeRenderArgumentTables(frameSlot: 0) { firstResources.append($0) })
        XCTAssertFalse(firstTables === secondTables)

        pool.reset(frameSlot: 0)
        var reusedResources = [MTLResource]()
        let reusedTables = try XCTUnwrap(pool.makeRenderArgumentTables(frameSlot: 0) { reusedResources.append($0) })
        XCTAssertTrue(firstTables === reusedTables)

        XCTAssertTrue(reusedTables.setVertexBuffer(buffer, offset: 0, index: .VertexUniforms))
        XCTAssertTrue(firstResources.isEmpty)
        XCTAssertEqual(reusedResources.count, 1)
        XCTAssertTrue(reusedResources[0] === buffer)
    }
}
