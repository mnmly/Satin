import Foundation
import Metal
@testable import Satin
import XCTest

/// Micro-benchmarks for the Satin Metal 4 wrapper's per-frame fixed-cost hot spots.
/// Each test runs N iterations of a single subsystem call and prints its mean cost.
/// Compare these numbers against the per-frame budget reported by
/// `Metal4BackendPerfTests` to see which subsystem is eating the time.
///
/// Run with:
///   swift test --filter Metal4HotPathProfileTests
final class Metal4HotPathProfileTests: XCTestCase {
    private static let iterations = 5000

    func testProfileRenderPassBridge() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }

        // Realistic G-buffer-style descriptor: color + depth + stencil + 5 MRT slots.
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        for i in 1...5 {
            descriptor.colorAttachments[i].loadAction = .clear
            descriptor.colorAttachments[i].storeAction = .store
        }
        descriptor.depthAttachment.loadAction = .clear
        descriptor.depthAttachment.storeAction = .store
        descriptor.depthAttachment.clearDepth = 1.0
        descriptor.stencilAttachment.loadAction = .clear
        descriptor.stencilAttachment.storeAction = .dontCare
        descriptor.renderTargetWidth = 1024
        descriptor.renderTargetHeight = 1024

        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0 ..< Self.iterations {
            _ = Metal4RenderPassBridge.makeDescriptor(from: descriptor)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let perCallMicros = elapsed / Double(Self.iterations) * 1_000_000.0
        print("Metal4RenderPassBridge.makeDescriptor: \(String(format: "%.3f", perCallMicros)) µs/call (\(Self.iterations) iters, \(String(format: "%.2f", elapsed * 1000)) ms total, 6 color + depth + stencil)")
    }

    func testProfileArgumentTableReset() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal unavailable.")
        }
        guard device.supportsFamily(.metal4) else {
            throw XCTSkip("Device does not support .metal4 family.")
        }

        let tables = try XCTUnwrap(Metal4ArgumentTables(device: device, resourceHandler: { _ in }))

        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0 ..< Self.iterations {
            tables.prepareForReuse(resourceHandler: { _ in })
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let perCallMicros = elapsed / Double(Self.iterations) * 1_000_000.0
        print("Metal4ArgumentTables.prepareForReuse: \(String(format: "%.3f", perCallMicros)) µs/call (\(Self.iterations) iters, \(String(format: "%.2f", elapsed * 1000)) ms total)")
    }

    func testProfileFrameCommandLifecycle() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal unavailable.")
        }
        guard device.supportsFamily(.metal4) else {
            throw XCTSkip("Device does not support .metal4 family.")
        }

        let support = try XCTUnwrap(Metal4Support(device: device, maxBuffersInFlight: 3))

        // begin() resets the allocator, clears the residency set, commits, and binds it
        // to the command buffer. commit() ends encoding and signals the slot semaphore.
        let semaphore = DispatchSemaphore(value: 0)
        let warmupFrames = 10
        for i in 0 ..< warmupFrames {
            let fc = try XCTUnwrap(support.makeFrameCommand(frameIndex: i))
            fc.commit { semaphore.signal() }
            semaphore.wait()
        }

        let start = CFAbsoluteTimeGetCurrent()
        for i in 0 ..< Self.iterations {
            let fc = try XCTUnwrap(support.makeFrameCommand(frameIndex: warmupFrames + i))
            fc.commit { semaphore.signal() }
            semaphore.wait()
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let perCallMicros = elapsed / Double(Self.iterations) * 1_000_000.0
        print("Metal4FrameCommand begin+empty-commit+wait: \(String(format: "%.3f", perCallMicros)) µs/cycle (\(Self.iterations) iters, \(String(format: "%.2f", elapsed * 1000)) ms total)")
    }

    func testProfileArgumentTableBinding() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 or newer.")
        }
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal unavailable.")
        }
        guard device.supportsFamily(.metal4) else {
            throw XCTSkip("Device does not support .metal4 family.")
        }

        let tables = try XCTUnwrap(Metal4ArgumentTables(device: device, resourceHandler: { _ in }))
        let buffer = try XCTUnwrap(device.makeBuffer(length: 1024, options: .storageModeShared))

        // Each draw in a typical scene binds ~3-4 buffers via setVertexBuffer/setFragmentBuffer.
        // Measure raw argument-table write cost for one buffer bind.
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0 ..< Self.iterations {
            _ = tables.setVertexBuffer(buffer, offset: 0, index: .VertexUniforms)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let perCallNanos = elapsed / Double(Self.iterations) * 1_000_000_000.0
        print("Metal4ArgumentTables.setVertexBuffer:    \(String(format: "%7.1f", perCallNanos)) ns/call (\(Self.iterations) iters, \(String(format: "%.2f", elapsed * 1000)) ms total)")
    }
}
