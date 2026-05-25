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
    private var resourceHandler: ((MTLResource) -> Void)?
    private static let nilResourceID = MTLResourceID(_impl: 0)

    // Track which slots were actually written since last reset so reuse clears
    // O(used) rather than O(maxBindCount). Profiling showed the previous
    // "zero every slot" reset cost ~11.7 µs/call across 137 MMIO writes.
    // Bitsets sized to the max binding count of each slot type — all slot ranges
    // fit comfortably in a single UInt64, so write-tracking is one bitwise-OR.
    private var dirtyVertexBuffers: UInt64 = 0       // up to 31 slots
    private var dirtyFragmentBuffers: UInt64 = 0     // up to 31 slots
    private var dirtyVertexTextures: UInt64 = 0      // up to ~17 slots
    private var dirtyFragmentTextures: UInt64 = 0    // up to 42 slots
    private var dirtyFragmentSamplers: UInt64 = 0    // up to 16 slots

    init?(device: MTLDevice, resourceHandler: ((MTLResource) -> Void)? = nil) {
        guard let vertexDescriptor = Metal4ArgumentBindingLayout.makeArgumentTableDescriptor(
            label: "Satin Metal 4 Vertex Arguments",
            maxBufferBindCount: Metal4ArgumentBindingLayout.maxBufferBindCount,
            maxTextureBindCount: VertexTextureIndex.Custom16.rawValue + 1,
            maxSamplerStateBindCount: 0
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
        self.resourceHandler = resourceHandler
    }

    func prepareForReuse(resourceHandler: ((MTLResource) -> Void)?) {
        self.resourceHandler = resourceHandler
        reset()
    }

    func bind(to renderEncoder: any MTL4RenderCommandEncoder) {
        renderEncoder.setArgumentTable(vertex, stages: .vertex)
        renderEncoder.setArgumentTable(fragment, stages: .fragment)
    }

    func useResource(_ resource: MTLResource) {
        resourceHandler?(resource)
    }

    // Argument tables are pooled per (frame slot, pass cursor). If pass N in frame
    // K-1 bound slot 7 and pass N in frame K does not, slot 7 would retain the
    // stale binding — which is fine unless the pipeline used in frame K reads
    // that slot. Clearing on reuse decouples binding lifetime from pipeline use,
    // matching MTL3 setVertexBuffer/setFragmentBuffer semantics where unbound
    // slots read as null. Track which slots were touched so we only re-zero those.
    /// Iterate set bits in a bitset and invoke `body` for each index, then clear.
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
        Self.drain(&dirtyVertexBuffers) { vertex.setAddress(0, index: $0) }
        Self.drain(&dirtyFragmentBuffers) { fragment.setAddress(0, index: $0) }
        Self.drain(&dirtyVertexTextures) { vertex.setTexture(Self.nilResourceID, index: $0) }
        Self.drain(&dirtyFragmentTextures) { fragment.setTexture(Self.nilResourceID, index: $0) }
        Self.drain(&dirtyFragmentSamplers) { fragment.setSamplerState(Self.nilResourceID, index: $0) }
    }

    @discardableResult
    func setVertexBuffer(_ buffer: MTLBuffer, offset: Int, index: VertexBufferIndex) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsBufferIndex(index.rawValue) else { return false }
        resourceHandler?(buffer)
        vertex.setAddress(buffer.gpuAddress + MTLGPUAddress(offset), index: index.rawValue)
        dirtyVertexBuffers |= 1 << index.rawValue
        return true
    }

    @discardableResult
    func setFragmentBuffer(_ buffer: MTLBuffer, offset: Int, index: FragmentBufferIndex) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsBufferIndex(index.rawValue) else { return false }
        resourceHandler?(buffer)
        fragment.setAddress(buffer.gpuAddress + MTLGPUAddress(offset), index: index.rawValue)
        dirtyFragmentBuffers |= 1 << index.rawValue
        return true
    }

    @discardableResult
    func setVertexTexture(_ texture: MTLTexture?, index: VertexTextureIndex) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsTextureIndex(index.rawValue) else { return false }
        guard let texture else { return true }
        resourceHandler?(texture)
        vertex.setTexture(texture.gpuResourceID, index: index.rawValue)
        dirtyVertexTextures |= 1 << index.rawValue
        return true
    }

    @discardableResult
    func setFragmentTexture(_ texture: MTLTexture?, index: FragmentTextureIndex) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsTextureIndex(index.rawValue) else { return false }
        guard let texture else { return true }
        resourceHandler?(texture)
        fragment.setTexture(texture.gpuResourceID, index: index.rawValue)
        dirtyFragmentTextures |= 1 << index.rawValue
        return true
    }

    @discardableResult
    func setFragmentSamplerState(_ samplerState: MTLSamplerState?, index: FragmentSamplerIndex) -> Bool {
        guard Metal4ArgumentBindingLayout.supportsSamplerStateIndex(index.rawValue) else { return false }
        guard let samplerState else { return true }
        fragment.setSamplerState(samplerState.gpuResourceID, index: index.rawValue)
        dirtyFragmentSamplers |= 1 << index.rawValue
        return true
    }
}
