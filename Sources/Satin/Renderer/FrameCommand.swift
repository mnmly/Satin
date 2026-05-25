//
//  FrameCommand.swift
//  Satin
//
//  Internal frame command wrappers used to stage backend-specific submission.
//

import Metal

public protocol SatinFrameCommand: AnyObject {
    var backend: MetalBackend { get }
    var frameIndex: Int { get }
}

internal protocol SatinCommittableFrameCommand: SatinFrameCommand {
    func commit()
    func commit(onCompleted: (() -> Void)?)
}

internal final class MetalFrameCommand: SatinCommittableFrameCommand {
    let backend: MetalBackend = .metal3
    let frameIndex: Int
    let commandBuffer: MTLCommandBuffer

    init(frameIndex: Int, commandBuffer: MTLCommandBuffer) {
        self.frameIndex = frameIndex
        self.commandBuffer = commandBuffer
    }

    func commit() {
        commit(onCompleted: nil)
    }

    func commit(onCompleted: (() -> Void)?) {
        if let onCompleted {
            commandBuffer.addCompletedHandler { _ in
                onCompleted()
            }
        }
        commandBuffer.commit()
    }
}

@available(macOS 26.0, iOS 26.0, visionOS 26.0, *)
internal final class Metal4FrameCommand: SatinCommittableFrameCommand {
    let backend: MetalBackend = .metal4
    let frameIndex: Int
    let frameSlot: Int
    let commandQueue: any MTL4CommandQueue
    let commandBuffer: any MTL4CommandBuffer
    let commandAllocator: any MTL4CommandAllocator
    private let residencySet: (any MTLResidencySet)?
    private let argumentTablePool: Metal4ArgumentTablePool
    private var isEncoding = false
    private var residencyNeedsCommit = false

    init(
        frameIndex: Int,
        frameSlot: Int,
        commandQueue: any MTL4CommandQueue,
        commandBuffer: any MTL4CommandBuffer,
        commandAllocator: any MTL4CommandAllocator,
        residencySet: (any MTLResidencySet)?,
        argumentTablePool: Metal4ArgumentTablePool
    ) {
        self.frameIndex = frameIndex
        self.frameSlot = frameSlot
        self.commandQueue = commandQueue
        self.commandBuffer = commandBuffer
        self.commandAllocator = commandAllocator
        self.residencySet = residencySet
        self.argumentTablePool = argumentTablePool
    }

    func begin() {
        commandAllocator.reset()
        commandBuffer.beginCommandBuffer(allocator: commandAllocator)
        residencyNeedsCommit = false
        if let residencySet {
            residencySet.removeAllAllocations()
            residencySet.commit()
            commandBuffer.useResidencySet(residencySet)
        }
        isEncoding = true
    }

    func useResource(_ resource: MTLResource) {
        guard let residencySet, !residencySet.containsAllocation(resource) else { return }
        residencySet.addAllocation(resource)
        residencyNeedsCommit = true
    }

    func makeRenderArgumentTables() -> Metal4ArgumentTables? {
        argumentTablePool.makeRenderArgumentTables(frameSlot: frameSlot, resourceHandler: useResource)
    }

    func end() {
        guard isEncoding else { return }
        if residencyNeedsCommit {
            residencySet?.commit()
            residencyNeedsCommit = false
        }
        commandBuffer.endCommandBuffer()
        isEncoding = false
    }

    func commit() {
        commit(onCompleted: nil)
    }

    func commit(onCompleted: (() -> Void)?) {
        end()
        if let onCompleted {
            let options = MTL4CommitOptions()
            options.addFeedbackHandler { _ in
                onCompleted()
            }
            commandQueue.commit([commandBuffer], options: options)
        } else {
            commandQueue.commit([commandBuffer])
        }
    }
}
