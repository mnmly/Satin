import Metal
@testable import Satin
import XCTest

final class Metal4RenderPassBridgeTests: XCTestCase {
    func testMetal4RenderPassBridgeCopiesSupportedDescriptorFields() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 render pass descriptors require OS 26 SDK runtime support.")
        }

        let descriptor = MTLRenderPassDescriptor()
        descriptor.renderTargetArrayLength = 2
        descriptor.imageblockSampleLength = 32
        descriptor.threadgroupMemoryLength = 64
        descriptor.tileWidth = 16
        descriptor.tileHeight = 8
        descriptor.defaultRasterSampleCount = 4
        descriptor.renderTargetWidth = 320
        descriptor.renderTargetHeight = 240
        descriptor.visibilityResultType = .accumulate
        descriptor.supportColorAttachmentMapping = true

        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 1.0)
        descriptor.depthAttachment.loadAction = .clear
        descriptor.depthAttachment.storeAction = .store
        descriptor.depthAttachment.clearDepth = 0.25
        descriptor.stencilAttachment.loadAction = .clear
        descriptor.stencilAttachment.storeAction = .store
        descriptor.stencilAttachment.clearStencil = 7
        let metal4Descriptor = Metal4RenderPassBridge.makeDescriptor(from: descriptor)

        XCTAssertEqual(metal4Descriptor.renderTargetArrayLength, 2)
        XCTAssertEqual(metal4Descriptor.imageblockSampleLength, 32)
        XCTAssertEqual(metal4Descriptor.threadgroupMemoryLength, 64)
        XCTAssertEqual(metal4Descriptor.tileWidth, 16)
        XCTAssertEqual(metal4Descriptor.tileHeight, 8)
        XCTAssertEqual(metal4Descriptor.defaultRasterSampleCount, 4)
        XCTAssertEqual(metal4Descriptor.renderTargetWidth, 320)
        XCTAssertEqual(metal4Descriptor.renderTargetHeight, 240)
        XCTAssertEqual(metal4Descriptor.visibilityResultType, .accumulate)
        XCTAssertTrue(metal4Descriptor.supportColorAttachmentMapping)

        XCTAssertEqual(metal4Descriptor.colorAttachments[0].loadAction, .clear)
        XCTAssertEqual(metal4Descriptor.colorAttachments[0].storeAction, .store)
        XCTAssertEqual(metal4Descriptor.colorAttachments[0].clearColor.red, 0.25)
        XCTAssertEqual(metal4Descriptor.colorAttachments[0].clearColor.green, 0.5)
        XCTAssertEqual(metal4Descriptor.colorAttachments[0].clearColor.blue, 0.75)
        XCTAssertEqual(metal4Descriptor.colorAttachments[0].clearColor.alpha, 1.0)
        XCTAssertEqual(metal4Descriptor.depthAttachment.loadAction, .clear)
        XCTAssertEqual(metal4Descriptor.depthAttachment.storeAction, .store)
        XCTAssertEqual(metal4Descriptor.depthAttachment.clearDepth, 0.25)
        XCTAssertEqual(metal4Descriptor.stencilAttachment.loadAction, .clear)
        XCTAssertEqual(metal4Descriptor.stencilAttachment.storeAction, .store)
        XCTAssertEqual(metal4Descriptor.stencilAttachment.clearStencil, 7)

    }

    func testMetal4RenderPassBridgeCopiesAttachmentsByValue() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 render pass descriptors require OS 26 SDK runtime support.")
        }

        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.depthAttachment.clearDepth = 0.5

        let metal4Descriptor = Metal4RenderPassBridge.makeDescriptor(from: descriptor)
        descriptor.colorAttachments[0].loadAction = .load
        descriptor.depthAttachment.clearDepth = 1.0

        XCTAssertEqual(metal4Descriptor.colorAttachments[0].loadAction, .clear)
        XCTAssertEqual(metal4Descriptor.depthAttachment.clearDepth, 0.5)
    }

    func testMetal4RenderPassBridgeCopiesCustomSamplePositions() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 render pass descriptors require OS 26 SDK runtime support.")
        }

        let descriptor = MTLRenderPassDescriptor()
        let positions: [MTLSamplePosition] = [
            MTLSamplePosition(x: 0.25, y: 0.25),
            MTLSamplePosition(x: 0.75, y: 0.25),
            MTLSamplePosition(x: 0.25, y: 0.75),
            MTLSamplePosition(x: 0.75, y: 0.75)
        ]
        descriptor.setSamplePositions(positions)

        let metal4Descriptor = Metal4RenderPassBridge.makeDescriptor(from: descriptor)
        XCTAssertEqual(metal4Descriptor.samplePositions.count, positions.count)
        for (forwarded, original) in zip(metal4Descriptor.samplePositions, positions) {
            XCTAssertEqual(forwarded.x, original.x)
            XCTAssertEqual(forwarded.y, original.y)
        }
    }

    func testMetal4RenderPassBridgeLeavesSamplePositionsEmptyWhenUnset() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 render pass descriptors require OS 26 SDK runtime support.")
        }

        let descriptor = MTLRenderPassDescriptor()
        let metal4Descriptor = Metal4RenderPassBridge.makeDescriptor(from: descriptor)
        XCTAssertTrue(metal4Descriptor.samplePositions.isEmpty)
    }
}
