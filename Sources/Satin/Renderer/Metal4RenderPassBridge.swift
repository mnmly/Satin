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

        let samplePositions = descriptor.getSamplePositions()
        if !samplePositions.isEmpty {
            result.samplePositions = samplePositions
        }

        return result
    }

    private static func copyColorAttachments(from source: MTLRenderPassDescriptor, to target: MTL4RenderPassDescriptor) {
        for index in 0 ..< maxColorAttachmentCount {
            target.colorAttachments[index] = source.colorAttachments[index]?.copy() as? MTLRenderPassColorAttachmentDescriptor
        }
    }
}
