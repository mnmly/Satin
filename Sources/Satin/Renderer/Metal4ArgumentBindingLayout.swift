//
//  Metal4ArgumentBindingLayout.swift
//  Satin
//
//  Metal 4 argument table limits and Satin binding compatibility checks.
//

import Metal

@available(macOS 26.0, iOS 26.0, visionOS 26.0, *)
internal enum Metal4ArgumentBindingLayout {
    static let maxBufferBindCount = 31
    static let maxTextureBindCount = 128
    static let maxSamplerStateBindCount = 16

    // Capacity of the fragment argument table's texture range. The renderer binds up to
    // `maxShadowTextures` directional-shadow textures starting at `FragmentTextureIndex.DirectShadow0`,
    // so the table must cover that whole span (otherwise binds past the end fail the encoder's
    // index check and trip the Metal 3 fallback for every frame with >1 shadowed light).
    // Single source of truth — derived from the shadow limits so the three numbers can't drift.
    static let maxFragmentTextureBindCount = min(
        maxTextureBindCount,
        FragmentTextureIndex.DirectShadow0.rawValue + maxShadowTextures
    )

    static var maxBufferIndex: Int { maxBufferBindCount - 1 }
    static var maxTextureIndex: Int { maxTextureBindCount - 1 }
    static var maxSamplerStateIndex: Int { maxSamplerStateBindCount - 1 }

    static func supportsBufferIndex(_ index: Int) -> Bool {
        index >= 0 && index <= maxBufferIndex
    }

    static func supportsTextureIndex(_ index: Int) -> Bool {
        index >= 0 && index <= maxTextureIndex
    }

    static func supportsSamplerStateIndex(_ index: Int) -> Bool {
        index >= 0 && index <= maxSamplerStateIndex
    }

    static var unsupportedVertexBufferIndices: [VertexBufferIndex] {
        VertexBufferIndex.allCases.filter { !supportsBufferIndex($0.rawValue) }
    }

    static var unsupportedFragmentSamplerIndices: [FragmentSamplerIndex] {
        [
            .Custom16,
            .Custom17,
            .Custom18,
            .Custom19,
            .Custom20,
            .Custom21,
            .Custom22,
            .Custom23,
            .Custom24,
            .Shadow0,
            .Shadow1,
            .Shadow2,
            .Shadow3,
            .Shadow4,
            .Shadow5,
            .Shadow6,
            .Shadow7
        ].filter { !supportsSamplerStateIndex($0.rawValue) }
    }

    static func makeArgumentTableDescriptor(
        label: String,
        maxBufferBindCount: Int,
        maxTextureBindCount: Int,
        maxSamplerStateBindCount: Int,
        supportAttributeStrides: Bool = false
    ) -> MTL4ArgumentTableDescriptor? {
        guard maxBufferBindCount >= 0,
              maxBufferBindCount <= Self.maxBufferBindCount,
              maxTextureBindCount >= 0,
              maxTextureBindCount <= Self.maxTextureBindCount,
              maxSamplerStateBindCount >= 0,
              maxSamplerStateBindCount <= Self.maxSamplerStateBindCount
        else { return nil }

        let descriptor = MTL4ArgumentTableDescriptor()
        descriptor.label = label
        descriptor.maxBufferBindCount = maxBufferBindCount
        descriptor.maxTextureBindCount = maxTextureBindCount
        descriptor.maxSamplerStateBindCount = maxSamplerStateBindCount
        descriptor.initializeBindings = true
        descriptor.supportAttributeStrides = supportAttributeStrides
        return descriptor
    }
}

/// Fixed-capacity dirty-slot tracker for argument tables. `mark` is a single bitwise-OR;
/// `drain` visits each set bit in O(set bits) and clears. Two 64-bit words cover the full
/// Metal argument-table index range (0..<128 = `maxTextureBindCount`), so it can track the
/// fragment-texture slots that now extend past index 63 — a single `UInt64` would shift past
/// its width (`1 << index`) and silently corrupt for those slots.
internal struct DirtySlotMask {
    private var word0: UInt64 = 0
    private var word1: UInt64 = 0

    @inline(__always)
    mutating func mark(_ index: Int) {
        if index < 64 {
            word0 |= 1 << UInt64(index)
        } else {
            word1 |= 1 << UInt64(index - 64)
        }
    }

    @inline(__always)
    mutating func drain(_ body: (Int) -> Void) {
        var bits = word0
        while bits != 0 {
            let i = bits.trailingZeroBitCount
            body(i)
            bits &= bits &- 1
        }
        word0 = 0

        bits = word1
        while bits != 0 {
            let i = bits.trailingZeroBitCount
            body(64 + i)
            bits &= bits &- 1
        }
        word1 = 0
    }
}
