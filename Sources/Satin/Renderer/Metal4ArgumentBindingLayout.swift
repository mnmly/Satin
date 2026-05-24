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
