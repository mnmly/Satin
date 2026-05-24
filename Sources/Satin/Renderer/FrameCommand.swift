//
//  FrameCommand.swift
//  Satin
//
//  Internal frame command wrappers used to stage backend-specific submission.
//

import Metal

internal protocol SatinFrameCommand {
    var backend: MetalBackend { get }
    var frameIndex: Int { get }
}

internal final class MetalFrameCommand: SatinFrameCommand {
    let backend: MetalBackend = .metal3
    let frameIndex: Int
    let commandBuffer: MTLCommandBuffer

    init(frameIndex: Int, commandBuffer: MTLCommandBuffer) {
        self.frameIndex = frameIndex
        self.commandBuffer = commandBuffer
    }

    func commit() {
        commandBuffer.commit()
    }
}

@available(macOS 26.0, iOS 26.0, visionOS 26.0, *)
internal final class Metal4FrameCommand: SatinFrameCommand {
    let backend: MetalBackend = .metal4
    let frameIndex: Int
    let commandQueue: any MTL4CommandQueue
    let commandBuffer: any MTL4CommandBuffer
    let commandAllocator: any MTL4CommandAllocator

    init(
        frameIndex: Int,
        commandQueue: any MTL4CommandQueue,
        commandBuffer: any MTL4CommandBuffer,
        commandAllocator: any MTL4CommandAllocator
    ) {
        self.frameIndex = frameIndex
        self.commandQueue = commandQueue
        self.commandBuffer = commandBuffer
        self.commandAllocator = commandAllocator
    }

    func begin() {
        commandAllocator.reset()
        commandBuffer.beginCommandBuffer(allocator: commandAllocator)
    }

    func end() {
        commandBuffer.endCommandBuffer()
    }

    func commit() {
        commandQueue.commit([commandBuffer])
    }
}
