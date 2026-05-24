import Metal
@testable import Satin
import XCTest

final class Metal4ArgumentBindingLayoutTests: XCTestCase {
    func testMetal4ArgumentBindingLayoutTracksSatinIncompatibleSlots() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 argument table limits require OS 26 SDK runtime support.")
        }

        XCTAssertEqual(Metal4ArgumentBindingLayout.maxBufferBindCount, 31)
        XCTAssertEqual(Metal4ArgumentBindingLayout.maxTextureBindCount, 128)
        XCTAssertEqual(Metal4ArgumentBindingLayout.maxSamplerStateBindCount, 16)

        XCTAssertTrue(Metal4ArgumentBindingLayout.supportsBufferIndex(VertexBufferIndex.Custom10.rawValue))
        XCTAssertFalse(Metal4ArgumentBindingLayout.supportsBufferIndex(VertexBufferIndex.Custom11.rawValue))
        XCTAssertEqual(Metal4ArgumentBindingLayout.unsupportedVertexBufferIndices, [.Custom11])

        XCTAssertTrue(Metal4ArgumentBindingLayout.supportsSamplerStateIndex(FragmentSamplerIndex.Custom15.rawValue))
        XCTAssertFalse(Metal4ArgumentBindingLayout.supportsSamplerStateIndex(FragmentSamplerIndex.Custom16.rawValue))
        XCTAssertTrue(Metal4ArgumentBindingLayout.unsupportedFragmentSamplerIndices.contains(.Shadow7))

        XCTAssertTrue(Metal4ArgumentBindingLayout.supportsTextureIndex(FragmentTextureIndex.DirectShadow0.rawValue))
    }

    func testMetal4ArgumentBindingLayoutBuildsBoundedDescriptors() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 argument table descriptors require OS 26 SDK runtime support.")
        }

        let descriptor = try XCTUnwrap(Metal4ArgumentBindingLayout.makeArgumentTableDescriptor(
            label: "Satin Vertex Arguments",
            maxBufferBindCount: 31,
            maxTextureBindCount: 0,
            maxSamplerStateBindCount: 0,
            supportAttributeStrides: true
        ))

        XCTAssertEqual(descriptor.label, "Satin Vertex Arguments")
        XCTAssertEqual(descriptor.maxBufferBindCount, 31)
        XCTAssertEqual(descriptor.maxTextureBindCount, 0)
        XCTAssertEqual(descriptor.maxSamplerStateBindCount, 0)
        XCTAssertTrue(descriptor.initializeBindings)
        XCTAssertTrue(descriptor.supportAttributeStrides)

        XCTAssertNil(Metal4ArgumentBindingLayout.makeArgumentTableDescriptor(
            label: "Too Many Buffers",
            maxBufferBindCount: 32,
            maxTextureBindCount: 0,
            maxSamplerStateBindCount: 0
        ))
    }
}
