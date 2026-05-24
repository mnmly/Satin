//
//  Metal4Support.swift
//  Satin
//
//  Internal scaffolding for Satin's opt-in Metal 4 backend.
//

import Metal

@available(macOS 26.0, iOS 26.0, visionOS 26.0, *)
internal final class Metal4Support {
    let commandQueue: any MTL4CommandQueue
    let commandBuffer: any MTL4CommandBuffer
    let commandAllocators: [any MTL4CommandAllocator]

    init?(device: MTLDevice, maxBuffersInFlight: Int) {
        guard let commandQueue = device.makeMTL4CommandQueue(),
              let commandBuffer = device.makeCommandBuffer()
        else { return nil }

        var commandAllocators = [any MTL4CommandAllocator]()
        commandAllocators.reserveCapacity(maxBuffersInFlight)

        for _ in 0 ..< maxBuffersInFlight {
            guard let commandAllocator = device.makeCommandAllocator() else {
                return nil
            }
            commandAllocators.append(commandAllocator)
        }

        self.commandQueue = commandQueue
        self.commandBuffer = commandBuffer
        self.commandAllocators = commandAllocators
    }

    func makeFrameCommand(frameIndex: Int) -> Metal4FrameCommand? {
        guard !commandAllocators.isEmpty else { return nil }
        let frameSlot = frameIndex % commandAllocators.count
        let frameCommand = Metal4FrameCommand(
            frameIndex: frameIndex,
            commandQueue: commandQueue,
            commandBuffer: commandBuffer,
            commandAllocator: commandAllocators[frameSlot]
        )
        frameCommand.begin()
        return frameCommand
    }
}
