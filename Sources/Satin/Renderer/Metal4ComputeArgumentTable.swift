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

    init?(device: MTLDevice) {
        guard let descriptor = Metal4ArgumentBindingLayout.makeArgumentTableDescriptor(
            label: "Satin Metal 4 Compute Arguments",
            maxBufferBindCount: ComputeBufferIndex.TessellationIndices.rawValue + 1,
            maxTextureBindCount: ComputeTextureIndex.Custom10.rawValue + 1,
            maxSamplerStateBindCount: 0
        ),
        let table = try? device.makeArgumentTable(descriptor: descriptor)
        else { return nil }

        self.table = table
    }

    func bind(to computeEncoder: any MTL4ComputeCommandEncoder) {
        computeEncoder.setArgumentTable(table)
    }

    @discardableResult
    func setBuffer(_ buffer: MTLBuffer, offset: Int, index: ComputeBufferIndex) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsBufferIndex(index.rawValue) else { return false }
        table.setAddress(buffer.gpuAddress + MTLGPUAddress(offset), index: index.rawValue)
        return true
    }

    @discardableResult
    func setBuffer(_ buffer: MTLBuffer, offset: Int, index: Int) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsBufferIndex(index) else { return false }
        table.setAddress(buffer.gpuAddress + MTLGPUAddress(offset), index: index)
        return true
    }

    @discardableResult
    func setTexture(_ texture: MTLTexture?, index: ComputeTextureIndex) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsTextureIndex(index.rawValue) else { return false }
        guard let texture else { return true }
        table.setTexture(texture.gpuResourceID, index: index.rawValue)
        return true
    }

    @discardableResult
    func setTexture(_ texture: MTLTexture?, index: Int) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsTextureIndex(index) else { return false }
        guard let texture else { return true }
        table.setTexture(texture.gpuResourceID, index: index)
        return true
    }
}
