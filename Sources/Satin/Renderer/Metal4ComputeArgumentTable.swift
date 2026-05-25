//
//  Metal4ComputeArgumentTable.swift
//  Satin
//
//  Internal Metal 4 compute argument table storage for Satin's compute binding layout.
//

import Metal

@available(macOS 26.0, iOS 26.0, visionOS 26.0, *)
internal final class Metal4ComputeArgumentTable {
    let table: any MTL4ArgumentTable
    private var resourceHandler: ((MTLResource) -> Void)?
    private static let nilResourceID = MTLResourceID(_impl: 0)
    private static let maxBufferIndex = ComputeBufferIndex.TessellationIndices.rawValue
    private static let maxTextureIndex = ComputeTextureIndex.Custom10.rawValue

    // Track which slots were written since last reset using bitsets (single
    // bitwise-OR per bind, O(used) drain on reset). Matches the optimization in
    // Metal4ArgumentTables.
    private var dirtyBuffers: UInt64 = 0
    private var dirtyTextures: UInt64 = 0

    init?(device: MTLDevice, resourceHandler: ((MTLResource) -> Void)? = nil) {
        guard let descriptor = Metal4ArgumentBindingLayout.makeArgumentTableDescriptor(
            label: "Satin Metal 4 Compute Arguments",
            maxBufferBindCount: Self.maxBufferIndex + 1,
            maxTextureBindCount: Self.maxTextureIndex + 1,
            maxSamplerStateBindCount: 0
        ),
        let table = try? device.makeArgumentTable(descriptor: descriptor)
        else { return nil }

        self.table = table
        self.resourceHandler = resourceHandler
    }

    func prepareForReuse(resourceHandler: ((MTLResource) -> Void)?) {
        self.resourceHandler = resourceHandler
        reset()
    }

    @inline(__always)
    private static func drain(_ mask: inout UInt64, body: (Int) -> Void) {
        var bits = mask
        while bits != 0 {
            let i = bits.trailingZeroBitCount
            body(i)
            bits &= bits &- 1
        }
        mask = 0
    }

    private func reset() {
        Self.drain(&dirtyBuffers) { table.setAddress(0, index: $0) }
        Self.drain(&dirtyTextures) { table.setTexture(Self.nilResourceID, index: $0) }
    }

    func bind(to computeEncoder: any MTL4ComputeCommandEncoder) {
        computeEncoder.setArgumentTable(table)
    }

    @discardableResult
    func setBuffer(_ buffer: MTLBuffer, offset: Int, index: ComputeBufferIndex) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsBufferIndex(index.rawValue) else { return false }
        resourceHandler?(buffer)
        table.setAddress(buffer.gpuAddress + MTLGPUAddress(offset), index: index.rawValue)
        dirtyBuffers |= 1 << index.rawValue
        return true
    }

    @discardableResult
    func setBuffer(_ buffer: MTLBuffer, offset: Int, index: Int) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsBufferIndex(index) else { return false }
        resourceHandler?(buffer)
        table.setAddress(buffer.gpuAddress + MTLGPUAddress(offset), index: index)
        dirtyBuffers |= 1 << index
        return true
    }

    @discardableResult
    func setTexture(_ texture: MTLTexture?, index: ComputeTextureIndex) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsTextureIndex(index.rawValue) else { return false }
        guard let texture else { return true }
        resourceHandler?(texture)
        table.setTexture(texture.gpuResourceID, index: index.rawValue)
        dirtyTextures |= 1 << index.rawValue
        return true
    }

    @discardableResult
    func setTexture(_ texture: MTLTexture?, index: Int) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsTextureIndex(index) else { return false }
        guard let texture else { return true }
        resourceHandler?(texture)
        table.setTexture(texture.gpuResourceID, index: index)
        dirtyTextures |= 1 << index
        return true
    }
}
