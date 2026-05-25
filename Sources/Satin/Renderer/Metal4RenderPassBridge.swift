//
//  Metal4RenderPassBridge.swift
//  Satin
//
//  Availability-scoped bridge from Satin's existing render pass state to Metal 4.
//

import Metal

@available(macOS 26.0, iOS 26.0, visionOS 26.0, *)
internal enum Metal4RenderPassBridge {
    private static let maxColorAttachmentCount = 8

    static func makeDescriptor(from descriptor: MTLRenderPassDescriptor) -> MTL4RenderPassDescriptor {
        let result = MTL4RenderPassDescriptor()

        copyColorAttachments(from: descriptor, to: result)
        result.depthAttachment = (descriptor.depthAttachment.copy() as! MTLRenderPassDepthAttachmentDescriptor)
        result.stencilAttachment = (descriptor.stencilAttachment.copy() as! MTLRenderPassStencilAttachmentDescriptor)

        result.visibilityResultBuffer = descriptor.visibilityResultBuffer
        result.renderTargetArrayLength = descriptor.renderTargetArrayLength
        result.imageblockSampleLength = descriptor.imageblockSampleLength
        result.threadgroupMemoryLength = descriptor.threadgroupMemoryLength
        result.tileWidth = descriptor.tileWidth
        result.tileHeight = descriptor.tileHeight
        result.defaultRasterSampleCount = descriptor.defaultRasterSampleCount
        result.renderTargetWidth = descriptor.renderTargetWidth
        result.renderTargetHeight = descriptor.renderTargetHeight
        result.rasterizationRateMap = descriptor.rasterizationRateMap
        result.visibilityResultType = descriptor.visibilityResultType
        result.supportColorAttachmentMapping = descriptor.supportColorAttachmentMapping

        // MTL4RenderPassDescriptor has sample-position selectors in Objective-C, but the
        // current Swift overlay does not expose them. Keep custom sample positions on the
        // classic path until Swift exposes a public MTL4 accessor.
        assertNoCustomSamplePositions(descriptor)

        return result
    }

    private static func assertNoCustomSamplePositions(_ descriptor: MTLRenderPassDescriptor) {
        #if DEBUG
        let positions = descriptor.getSamplePositions()
        if !positions.isEmpty {
            assertionFailure("Metal 4 render pass bridge drops \(positions.count) custom sample position(s). Override on the classic Metal 3 path until the Swift overlay exposes MTL4 sample-position accessors.")
        }
        #endif
    }

    private static func copyColorAttachments(from source: MTLRenderPassDescriptor, to target: MTL4RenderPassDescriptor) {
        for index in 0 ..< maxColorAttachmentCount {
            target.colorAttachments[index] = source.colorAttachments[index]?.copy() as? MTLRenderPassColorAttachmentDescriptor
        }
    }

}
