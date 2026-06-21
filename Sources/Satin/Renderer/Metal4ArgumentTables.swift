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

    // Per-table slot counts — each table is sized to exactly what Satin's binding layout uses.
    // Setters guard against these (the table's real capacity) rather than the device-wide
    // maximum, so a bind that fits succeeds and a bind past the end fails cleanly (→ fallback)
    // instead of hitting a Metal range-validation error.
    private static let vertexBufferBindCount = Metal4ArgumentBindingLayout.maxBufferBindCount
    private static let vertexTextureBindCount = VertexTextureIndex.Custom16.rawValue + 1
    private static let fragmentBufferBindCount = FragmentBufferIndex.DirectShadowMatrices.rawValue + 1
    private static let fragmentTextureBindCount = Metal4ArgumentBindingLayout.maxFragmentTextureBindCount
    private static let fragmentSamplerBindCount = Metal4ArgumentBindingLayout.maxSamplerStateBindCount

    // Track which slots were actually written since last reset so reuse clears
    // O(used) rather than O(maxBindCount). Profiling showed the previous
    // "zero every slot" reset cost ~11.7 µs/call across 137 MMIO writes.
    // DirtySlotMask spans the full Metal index range in two words — the fragment
    // texture slots now extend past index 63 (DirectShadow0 + maxShadowTextures),
    // which a single UInt64 could not track without shifting past its width.
    private var dirtyVertexBuffers = DirtySlotMask()
    private var dirtyFragmentBuffers = DirtySlotMask()
    private var dirtyVertexTextures = DirtySlotMask()
    private var dirtyFragmentTextures = DirtySlotMask()
    private var dirtyFragmentSamplers = DirtySlotMask()

    init?(device: MTLDevice, resourceHandler: ((MTLResource) -> Void)? = nil) {
        guard let vertexDescriptor = Metal4ArgumentBindingLayout.makeArgumentTableDescriptor(
            label: "Satin Metal 4 Vertex Arguments",
            maxBufferBindCount: Self.vertexBufferBindCount,
            maxTextureBindCount: Self.vertexTextureBindCount,
            maxSamplerStateBindCount: 0
        ),
        let fragmentDescriptor = Metal4ArgumentBindingLayout.makeArgumentTableDescriptor(
            label: "Satin Metal 4 Fragment Arguments",
            maxBufferBindCount: Self.fragmentBufferBindCount,
            maxTextureBindCount: Self.fragmentTextureBindCount,
            maxSamplerStateBindCount: Self.fragmentSamplerBindCount
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
    private func reset() {
        dirtyVertexBuffers.drain { vertex.setAddress(0, index: $0) }
        dirtyFragmentBuffers.drain { fragment.setAddress(0, index: $0) }
        dirtyVertexTextures.drain { vertex.setTexture(Self.nilResourceID, index: $0) }
        dirtyFragmentTextures.drain { fragment.setTexture(Self.nilResourceID, index: $0) }
        dirtyFragmentSamplers.drain { fragment.setSamplerState(Self.nilResourceID, index: $0) }
    }

    // Bindings are keyed by raw index against each table's real capacity. The typed
    // enums remain for naming at call sites, but the Metal 4 path no longer requires a
    // matching enum case — contiguous slots without an enum (e.g. DirectShadow0 + N) and
    // custom material indices within capacity now bind instead of tripping the fallback.

    @discardableResult
    func setVertexBuffer(_ buffer: MTLBuffer, offset: Int, index: VertexBufferIndex) -> Bool {
        setVertexBuffer(buffer, offset: offset, index: index.rawValue)
    }

    @discardableResult
    func setVertexBuffer(_ buffer: MTLBuffer, offset: Int, index: Int) -> Bool {
        guard index >= 0, index < Self.vertexBufferBindCount else { return false }
        resourceHandler?(buffer)
        vertex.setAddress(buffer.gpuAddress + MTLGPUAddress(offset), index: index)
        dirtyVertexBuffers.mark(index)
        return true
    }

    @discardableResult
    func setFragmentBuffer(_ buffer: MTLBuffer, offset: Int, index: FragmentBufferIndex) -> Bool {
        setFragmentBuffer(buffer, offset: offset, index: index.rawValue)
    }

    @discardableResult
    func setFragmentBuffer(_ buffer: MTLBuffer, offset: Int, index: Int) -> Bool {
        guard index >= 0, index < Self.fragmentBufferBindCount else { return false }
        resourceHandler?(buffer)
        fragment.setAddress(buffer.gpuAddress + MTLGPUAddress(offset), index: index)
        dirtyFragmentBuffers.mark(index)
        return true
    }

    @discardableResult
    func setVertexTexture(_ texture: MTLTexture?, index: VertexTextureIndex) -> Bool {
        setVertexTexture(texture, index: index.rawValue)
    }

    @discardableResult
    func setVertexTexture(_ texture: MTLTexture?, index: Int) -> Bool {
        guard index >= 0, index < Self.vertexTextureBindCount else { return false }
        guard let texture else { return true }
        resourceHandler?(texture)
        vertex.setTexture(texture.gpuResourceID, index: index)
        dirtyVertexTextures.mark(index)
        return true
    }

    @discardableResult
    func setFragmentTexture(_ texture: MTLTexture?, index: FragmentTextureIndex) -> Bool {
        setFragmentTexture(texture, index: index.rawValue)
    }

    @discardableResult
    func setFragmentTexture(_ texture: MTLTexture?, index: Int) -> Bool {
        guard index >= 0, index < Self.fragmentTextureBindCount else { return false }
        guard let texture else { return true }
        resourceHandler?(texture)
        fragment.setTexture(texture.gpuResourceID, index: index)
        dirtyFragmentTextures.mark(index)
        return true
    }

    @discardableResult
    func setFragmentSamplerState(_ samplerState: MTLSamplerState?, index: FragmentSamplerIndex) -> Bool {
        setFragmentSamplerState(samplerState, index: index.rawValue)
    }

    @discardableResult
    func setFragmentSamplerState(_ samplerState: MTLSamplerState?, index: Int) -> Bool {
        guard index >= 0, index < Self.fragmentSamplerBindCount else { return false }
        guard let samplerState else { return true }
        fragment.setSamplerState(samplerState.gpuResourceID, index: index)
        dirtyFragmentSamplers.mark(index)
        return true
    }
}
