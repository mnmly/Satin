//
//  Metal4ArgumentTables.swift
//  Satin
//
//  Internal Metal 4 argument table storage for Satin's current binding layout.
//

import Metal

@available(macOS 26.0, iOS 26.0, visionOS 26.0, *)
internal final class Metal4ArgumentTables {
    let vertex: any MTL4ArgumentTable
    let fragment: any MTL4ArgumentTable

    init?(device: MTLDevice) {
        guard let vertexDescriptor = Metal4ArgumentBindingLayout.makeArgumentTableDescriptor(
            label: "Satin Metal 4 Vertex Arguments",
            maxBufferBindCount: Metal4ArgumentBindingLayout.maxBufferBindCount,
            maxTextureBindCount: 17,
            maxSamplerStateBindCount: 0,
            supportAttributeStrides: true
        ),
        let fragmentDescriptor = Metal4ArgumentBindingLayout.makeArgumentTableDescriptor(
            label: "Satin Metal 4 Fragment Arguments",
            maxBufferBindCount: FragmentBufferIndex.DirectShadowMatrices.rawValue + 1,
            maxTextureBindCount: FragmentTextureIndex.DirectShadow0.rawValue + 1,
            maxSamplerStateBindCount: Metal4ArgumentBindingLayout.maxSamplerStateBindCount
        ),
        let vertex = try? device.makeArgumentTable(descriptor: vertexDescriptor),
        let fragment = try? device.makeArgumentTable(descriptor: fragmentDescriptor)
        else { return nil }

        self.vertex = vertex
        self.fragment = fragment
    }

    func bind(to renderEncoder: any MTL4RenderCommandEncoder) {
        renderEncoder.setArgumentTable(vertex, stages: .vertex)
        renderEncoder.setArgumentTable(fragment, stages: .fragment)
    }

    @discardableResult
    func setVertexBuffer(_ buffer: MTLBuffer, offset: Int, index: VertexBufferIndex) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsBufferIndex(index.rawValue) else { return false }
        vertex.setAddress(buffer.gpuAddress + MTLGPUAddress(offset), index: index.rawValue)
        return true
    }

    @discardableResult
    func setFragmentBuffer(_ buffer: MTLBuffer, offset: Int, index: FragmentBufferIndex) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsBufferIndex(index.rawValue) else { return false }
        fragment.setAddress(buffer.gpuAddress + MTLGPUAddress(offset), index: index.rawValue)
        return true
    }

    @discardableResult
    func setVertexTexture(_ texture: MTLTexture?, index: VertexTextureIndex) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsTextureIndex(index.rawValue) else { return false }
        guard let texture else { return true }
        vertex.setTexture(texture.gpuResourceID, index: index.rawValue)
        return true
    }

    @discardableResult
    func setFragmentTexture(_ texture: MTLTexture?, index: FragmentTextureIndex) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsTextureIndex(index.rawValue) else { return false }
        guard let texture else { return true }
        fragment.setTexture(texture.gpuResourceID, index: index.rawValue)
        return true
    }

    @discardableResult
    func setFragmentSamplerState(_ samplerState: MTLSamplerState?, index: FragmentSamplerIndex) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsSamplerStateIndex(index.rawValue) else { return false }
        guard let samplerState else { return true }
        fragment.setSamplerState(samplerState.gpuResourceID, index: index.rawValue)
        return true
    }
}
