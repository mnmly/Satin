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

    func testFragmentTextureCapacityCoversFullShadowRange() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 argument table limits require OS 26 SDK runtime support.")
        }

        // The fragment table must hold every directional-shadow texture the renderer can bind:
        // they start at DirectShadow0 and run for maxShadowTextures slots. If this regresses to
        // the old DirectShadow0 + 1 sizing, any scene with >1 shadowed light silently falls back
        // to Metal 3 every frame.
        let required = FragmentTextureIndex.DirectShadow0.rawValue + maxShadowTextures
        XCTAssertGreaterThanOrEqual(Metal4ArgumentBindingLayout.maxFragmentTextureBindCount, required)
        XCTAssertLessThanOrEqual(
            Metal4ArgumentBindingLayout.maxFragmentTextureBindCount,
            Metal4ArgumentBindingLayout.maxTextureBindCount
        )
        XCTAssertGreaterThan(
            Metal4ArgumentBindingLayout.maxFragmentTextureBindCount,
            FragmentTextureIndex.DirectShadow0.rawValue + 1
        )
    }

    func testDirtySlotMaskTracksAndClearsSlotsAcrossWordBoundary() {
        // Hardware-independent guard for the bitset widening: a single UInt64 could not track
        // fragment-texture slots past index 63 (DirectShadow0 + maxShadowTextures reaches 88).
        var mask = DirtySlotMask()
        let marked = [0, 1, 63, 64, 65, 88, 127]
        for index in marked { mask.mark(index) }

        var visited = [Int]()
        mask.drain { visited.append($0) }
        XCTAssertEqual(visited, marked)

        // drain must clear; a second drain visits nothing.
        var second = [Int]()
        mask.drain { second.append($0) }
        XCTAssertTrue(second.isEmpty)
    }
}
