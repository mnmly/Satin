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
    let residencySets: [any MTLResidencySet]
    private let argumentTablePool: Metal4ArgumentTablePool

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

        let residencySetDescriptor = MTLResidencySetDescriptor()
        residencySetDescriptor.label = "Satin Metal 4 Residency Set"
        residencySetDescriptor.initialCapacity = 256

        // Residency sets are paired with command allocators and frame slots.
        // The renderer's in-flight semaphore protects slot reuse before reset.
        var residencySets = [any MTLResidencySet]()
        residencySets.reserveCapacity(maxBuffersInFlight)
        for _ in 0 ..< maxBuffersInFlight {
            guard let residencySet = try? device.makeResidencySet(descriptor: residencySetDescriptor) else {
                return nil
            }
            residencySets.append(residencySet)
        }

        self.commandQueue = commandQueue
        self.commandBuffer = commandBuffer
        self.commandAllocators = commandAllocators
        self.residencySets = residencySets
        self.argumentTablePool = Metal4ArgumentTablePool(device: device, frameSlotCount: maxBuffersInFlight)
    }

    func makeFrameCommand(frameIndex: Int) -> Metal4FrameCommand? {
        guard !commandAllocators.isEmpty else { return nil }
        let frameSlot = frameIndex % commandAllocators.count
        argumentTablePool.reset(frameSlot: frameSlot)
        let frameCommand = Metal4FrameCommand(
            frameIndex: frameIndex,
            frameSlot: frameSlot,
            commandQueue: commandQueue,
            commandBuffer: commandBuffer,
            commandAllocator: commandAllocators[frameSlot],
            residencySet: residencySets.indices.contains(frameSlot) ? residencySets[frameSlot] : nil,
            argumentTablePool: argumentTablePool
        )
        frameCommand.begin()
        return frameCommand
    }

    func makeRenderCommand(
        renderPassDescriptor: MTLRenderPassDescriptor,
        options: MTL4RenderEncoderOptions = []
    ) -> Metal4RenderCommand? {
        let metal4Descriptor = Metal4RenderPassBridge.makeDescriptor(from: renderPassDescriptor)
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: metal4Descriptor,
            options: options
        ) else { return nil }

        return Metal4RenderCommand(
            renderPassDescriptor: metal4Descriptor,
            renderEncoder: renderEncoder
        )
    }
}

@available(macOS 26.0, iOS 26.0, visionOS 26.0, *)
internal struct Metal4RenderCommand {
    let renderPassDescriptor: MTL4RenderPassDescriptor
    let renderEncoder: any MTL4RenderCommandEncoder
}

@available(macOS 26.0, iOS 26.0, visionOS 26.0, *)
internal final class Metal4ArgumentTablePool {
    private let device: MTLDevice
    private var renderTables: [[Metal4ArgumentTables]]
    private var renderCursors: [Int]

    init(device: MTLDevice, frameSlotCount: Int) {
        self.device = device
        self.renderTables = Array(repeating: [], count: frameSlotCount)
        self.renderCursors = Array(repeating: 0, count: frameSlotCount)
    }

    func reset(frameSlot: Int) {
        guard renderCursors.indices.contains(frameSlot) else { return }
        renderCursors[frameSlot] = 0
    }

    func makeRenderArgumentTables(frameSlot: Int, resourceHandler: @escaping (MTLResource) -> Void) -> Metal4ArgumentTables? {
        guard renderTables.indices.contains(frameSlot) else { return nil }
        let cursor = renderCursors[frameSlot]
        renderCursors[frameSlot] += 1

        if renderTables[frameSlot].indices.contains(cursor) {
            let tables = renderTables[frameSlot][cursor]
            tables.prepareForReuse(resourceHandler: resourceHandler)
            return tables
        }

        guard let tables = Metal4ArgumentTables(device: device, resourceHandler: resourceHandler) else {
            return nil
        }
        renderTables[frameSlot].append(tables)
        return tables
    }
}
