import Metal
@testable import Satin
import XCTest

final class ContextBackendTests: XCTestCase {
    private func makeDevice() -> MTLDevice? {
        MTLCreateSystemDefaultDevice()
    }

    func testContextDefaultsToMetal3Backend() throws {
        let device = try XCTUnwrap(makeDevice())
        let context = Context(device: device, sampleCount: 1, colorPixelFormat: .bgra8Unorm)

        XCTAssertEqual(context.requestedBackend, .metal3)
        XCTAssertEqual(context.backend, .metal3)
    }

    func testContextCanRequestMetal4WithFallback() throws {
        let device = try XCTUnwrap(makeDevice())
        let context = Context(device: device, backend: .metal4, sampleCount: 1, colorPixelFormat: .bgra8Unorm)

        XCTAssertEqual(context.requestedBackend, .metal4)
        XCTAssertTrue(context.backend == .metal4 || context.backend == .metal3)
    }

    func testBackendDerivedFromCapabilityMatchesDeviceSupport() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 SDK runtime support.")
        }
        let device = try XCTUnwrap(makeDevice())
        let context = Context(device: device, backend: .metal4, sampleCount: 1, colorPixelFormat: .bgra8Unorm)
        // backend now reflects device capability directly, without allocating the backend.
        XCTAssertEqual(context.backend, device.supportsFamily(.metal4) ? .metal4 : .metal3)
    }

    func testMetal4SupportIsLazilyResolvedAndCached() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 SDK runtime support.")
        }
        let device = try XCTUnwrap(makeDevice())
        guard device.supportsFamily(.metal4) else {
            throw XCTSkip("Metal 4 is not available on this device.")
        }
        let context = Context(device: device, backend: .metal4, sampleCount: 1, colorPixelFormat: .bgra8Unorm)
        let support = try XCTUnwrap(context.metal4Support)
        // Resolved once and cached — repeated access returns the same instance.
        XCTAssertTrue(context.metal4Support === support)
    }

    func testMetal4SupportAdoptsExternalCommandQueue() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 requires OS 26 SDK runtime support.")
        }
        let device = try XCTUnwrap(makeDevice())
        guard device.supportsFamily(.metal4), let queue = device.makeMTL4CommandQueue() else {
            throw XCTSkip("Metal 4 is not available on this device.")
        }
        // Guards risk: the lazy box must not drop the compositor queue that SpatialRenderer
        // injects, otherwise visionOS present would observe nothing.
        let context = Context(
            device: device,
            backend: .metal4,
            sampleCount: 1,
            colorPixelFormat: .bgra8Unorm,
            externalMetal4CommandQueue: queue
        )
        let support = try XCTUnwrap(context.metal4Support)
        XCTAssertTrue(support.commandQueue === queue)
    }
}
