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

    // Track which slots were written since last reset (single mark per bind, O(used)
    // drain on reset). Matches Metal4ArgumentTables; DirtySlotMask spans the full index
    // range so future slot growth can't shift past a single UInt64's width.
    private var dirtyBuffers = DirtySlotMask()
    private var dirtyTextures = DirtySlotMask()

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

    private func reset() {
        dirtyBuffers.drain { table.setAddress(0, index: $0) }
        dirtyTextures.drain { table.setTexture(Self.nilResourceID, index: $0) }
    }

    func bind(to computeEncoder: any MTL4ComputeCommandEncoder) {
        computeEncoder.setArgumentTable(table)
    }

    @discardableResult
    func setBuffer(_ buffer: MTLBuffer, offset: Int, index: ComputeBufferIndex) -> Bool {
        setBuffer(buffer, offset: offset, index: index.rawValue)
    }

    @discardableResult
    func setBuffer(_ buffer: MTLBuffer, offset: Int, index: Int) -> Bool {
        guard index >= 0, index <= Self.maxBufferIndex else { return false }
        resourceHandler?(buffer)
        table.setAddress(buffer.gpuAddress + MTLGPUAddress(offset), index: index)
        dirtyBuffers.mark(index)
        return true
    }

    @discardableResult
    func setTexture(_ texture: MTLTexture?, index: ComputeTextureIndex) -> Bool {
        setTexture(texture, index: index.rawValue)
    }

    @discardableResult
    func setTexture(_ texture: MTLTexture?, index: Int) -> Bool {
        guard index >= 0, index <= Self.maxTextureIndex else { return false }
        guard let texture else { return true }
        resourceHandler?(texture)
        table.setTexture(texture.gpuResourceID, index: index)
        dirtyTextures.mark(index)
        return true
    }
}
