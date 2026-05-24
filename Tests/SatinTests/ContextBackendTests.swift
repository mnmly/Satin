import Metal
import Satin
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
}
