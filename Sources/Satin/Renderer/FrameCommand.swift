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

    /// The classic Metal 3 command buffer, or nil on the Metal 4 backend. Use this in per-frame
    /// encoders that depend on `MTLCommandBuffer`-only APIs (e.g. Metal Performance Shaders):
    /// `guard let commandBuffer = frameCommand.metal3CommandBuffer else { return }`.
    var metal3CommandBuffer: MTLCommandBuffer? { get }
}

internal protocol SatinCommittableFrameCommand: SatinFrameCommand {
    func commit()
    func commit(onCompleted: (() -> Void)?)

    /// Build a backend-appropriate `RenderEncoderState` for the given pass descriptor, or nil
    /// if the encoder/argument tables can't be created. Keeps the Metal 3 vs Metal 4 branch
    /// (and its availability gating) on the concrete frame command instead of at call sites.
    func makeRenderEncoderState(descriptor: MTLRenderPassDescriptor) -> RenderEncoderState?
}

internal final class MetalFrameCommand: SatinCommittableFrameCommand {
    let backend: MetalBackend = .metal3
    let frameIndex: Int
    let commandBuffer: MTLCommandBuffer

    var metal3CommandBuffer: MTLCommandBuffer? { commandBuffer }

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

    func makeRenderEncoderState(descriptor: MTLRenderPassDescriptor) -> RenderEncoderState? {
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return nil
        }
        return RenderEncoderState(renderEncoder: renderEncoder)
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

    // No classic command buffer on the Metal 4 backend; MPS-style MTL3-only encoders use this
    // to detect and skip (or fall back) cleanly.
    var metal3CommandBuffer: MTLCommandBuffer? { nil }
    private let residencySet: (any MTLResidencySet)?
    private let argumentTablePool: Metal4ArgumentTablePool
    // Signalled from the commit feedback handler after the GPU finishes using this
    // slot's allocator / residency set. Metal4Support waits on this before reusing
    // the slot — so allocator reset is gated on GPU completion regardless of how
    // commit() was invoked.
    private let slotCompletionSemaphore: DispatchSemaphore
    private var isEncoding = false
    private var residencyNeedsCommit = false
    private var didSignalSlotCompletion = false
    private var pendingFallbackSignal: (event: any MTLSharedEvent, value: UInt64)?

    init(
        frameIndex: Int,
        frameSlot: Int,
        commandQueue: any MTL4CommandQueue,
        commandBuffer: any MTL4CommandBuffer,
        commandAllocator: any MTL4CommandAllocator,
        residencySet: (any MTLResidencySet)?,
        argumentTablePool: Metal4ArgumentTablePool,
        slotCompletionSemaphore: DispatchSemaphore
    ) {
        self.frameIndex = frameIndex
        self.frameSlot = frameSlot
        self.commandQueue = commandQueue
        self.commandBuffer = commandBuffer
        self.commandAllocator = commandAllocator
        self.residencySet = residencySet
        self.argumentTablePool = argumentTablePool
        self.slotCompletionSemaphore = slotCompletionSemaphore
    }

    deinit {
        // If the caller never committed, release the slot so Metal4Support doesn't
        // deadlock the next frame waiting on a signal that never comes.
        if !didSignalSlotCompletion {
            slotCompletionSemaphore.signal()
        }
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

    func makeRenderEncoderState(descriptor: MTLRenderPassDescriptor) -> RenderEncoderState? {
        let metal4Descriptor = Metal4RenderPassBridge.makeDescriptor(from: descriptor)
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: metal4Descriptor),
              let argumentTables = makeRenderArgumentTables()
        else { return nil }
        return RenderEncoderState(metal4RenderEncoder: renderEncoder, argumentTables: argumentTables)
    }

    func makeComputeArgumentTable() -> Metal4ComputeArgumentTable? {
        argumentTablePool.makeComputeArgumentTable(frameSlot: frameSlot, resourceHandler: useResource)
    }

    /// Arrange for the Metal 4 queue to signal `event` with `value` after the
    /// partial buffer commits. Pair with `encodeWaitForEvent` on the Metal 3
    /// fallback buffer so the GPU does not race the two queues on the drawable.
    func scheduleFallbackSignal(event: any MTLSharedEvent, value: UInt64) {
        pendingFallbackSignal = (event, value)
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
        // Always wire a feedback handler so the slot semaphore is released after
        // GPU completion — even when the caller doesn't supply onCompleted.
        let options = MTL4CommitOptions()
        let signalSlot: () -> Void = { [self] in
            guard !didSignalSlotCompletion else { return }
            didSignalSlotCompletion = true
            slotCompletionSemaphore.signal()
        }
        options.addFeedbackHandler { _ in
            signalSlot()
            onCompleted?()
        }
        commandQueue.commit([commandBuffer], options: options)
        if let pendingFallbackSignal {
            commandQueue.signalEvent(pendingFallbackSignal.event, value: pendingFallbackSignal.value)
            self.pendingFallbackSignal = nil
        }
    }
}
