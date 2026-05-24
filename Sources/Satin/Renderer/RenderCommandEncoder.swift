//
//  RenderCommandEncoder.swift
//  Satin
//
//  Internal render command interface for backend-specific encoder state.
//

import Metal

internal protocol SatinRenderCommandEncoder {
    var supportsTessellation: Bool { get }

    func setCullMode(_ cullMode: MTLCullMode)
    func setFrontFacing(_ windingOrder: MTLWinding)
    func setTriangleFillMode(_ triangleFillMode: MTLTriangleFillMode)
    func setRenderPipelineState(_ pipeline: MTLRenderPipelineState)
    func setDepthStencilState(_ depthStencilState: MTLDepthStencilState?)
    func setDepthClipMode(_ depthClipMode: MTLDepthClipMode)
    func setDepthBias(_ depthBias: Float, slopeScale: Float, clamp: Float)
    func setVertexBuffer(_ buffer: MTLBuffer, offset: Int, index: Int)
    func setFragmentBuffer(_ buffer: MTLBuffer, offset: Int, index: Int)
    func setVertexTexture(_ texture: MTLTexture?, index: Int)
    func setFragmentTexture(_ texture: MTLTexture?, index: Int)
    func setFragmentSamplerState(_ samplerState: MTLSamplerState?, index: Int)
    func drawPrimitives(type: MTLPrimitiveType, vertexStart: Int, vertexCount: Int, instanceCount: Int)
    func drawIndexedPrimitives(
        type: MTLPrimitiveType,
        indexCount: Int,
        indexType: MTLIndexType,
        indexBuffer: MTLBuffer,
        indexBufferOffset: Int,
        instanceCount: Int
    )
    func setTessellationFactorBuffer(_ buffer: MTLBuffer, offset: Int, instanceStride: Int)
    func drawPatches(
        numberOfPatchControlPoints: Int,
        patchStart: Int,
        patchCount: Int,
        patchIndexBuffer: MTLBuffer?,
        patchIndexBufferOffset: Int,
        instanceCount: Int,
        baseInstance: Int
    )
    func drawIndexedPatches(
        numberOfPatchControlPoints: Int,
        patchStart: Int,
        patchCount: Int,
        patchIndexBuffer: MTLBuffer?,
        patchIndexBufferOffset: Int,
        controlPointIndexBuffer: MTLBuffer,
        controlPointIndexBufferOffset: Int,
        instanceCount: Int,
        baseInstance: Int
    )
}

internal final class MetalRenderCommandEncoder: SatinRenderCommandEncoder {
    private let renderEncoder: MTLRenderCommandEncoder

    let supportsTessellation = true

    init(renderEncoder: MTLRenderCommandEncoder) {
        self.renderEncoder = renderEncoder
    }

    func setCullMode(_ cullMode: MTLCullMode) {
        renderEncoder.setCullMode(cullMode)
    }

    func setFrontFacing(_ windingOrder: MTLWinding) {
        renderEncoder.setFrontFacing(windingOrder)
    }

    func setTriangleFillMode(_ triangleFillMode: MTLTriangleFillMode) {
        renderEncoder.setTriangleFillMode(triangleFillMode)
    }

    func setRenderPipelineState(_ pipeline: MTLRenderPipelineState) {
        renderEncoder.setRenderPipelineState(pipeline)
    }

    func setDepthStencilState(_ depthStencilState: MTLDepthStencilState?) {
        renderEncoder.setDepthStencilState(depthStencilState)
    }

    func setDepthClipMode(_ depthClipMode: MTLDepthClipMode) {
        renderEncoder.setDepthClipMode(depthClipMode)
    }

    func setDepthBias(_ depthBias: Float, slopeScale: Float, clamp: Float) {
        renderEncoder.setDepthBias(depthBias, slopeScale: slopeScale, clamp: clamp)
    }

    func setVertexBuffer(_ buffer: MTLBuffer, offset: Int, index: Int) {
        renderEncoder.setVertexBuffer(buffer, offset: offset, index: index)
    }

    func setFragmentBuffer(_ buffer: MTLBuffer, offset: Int, index: Int) {
        renderEncoder.setFragmentBuffer(buffer, offset: offset, index: index)
    }

    func setVertexTexture(_ texture: MTLTexture?, index: Int) {
        renderEncoder.setVertexTexture(texture, index: index)
    }

    func setFragmentTexture(_ texture: MTLTexture?, index: Int) {
        renderEncoder.setFragmentTexture(texture, index: index)
    }

    func setFragmentSamplerState(_ samplerState: MTLSamplerState?, index: Int) {
        renderEncoder.setFragmentSamplerState(samplerState, index: index)
    }

    func drawPrimitives(type: MTLPrimitiveType, vertexStart: Int, vertexCount: Int, instanceCount: Int) {
        renderEncoder.drawPrimitives(
            type: type,
            vertexStart: vertexStart,
            vertexCount: vertexCount,
            instanceCount: instanceCount
        )
    }

    func drawIndexedPrimitives(
        type: MTLPrimitiveType,
        indexCount: Int,
        indexType: MTLIndexType,
        indexBuffer: MTLBuffer,
        indexBufferOffset: Int,
        instanceCount: Int
    ) {
        renderEncoder.drawIndexedPrimitives(
            type: type,
            indexCount: indexCount,
            indexType: indexType,
            indexBuffer: indexBuffer,
            indexBufferOffset: indexBufferOffset,
            instanceCount: instanceCount
        )
    }

    func setTessellationFactorBuffer(_ buffer: MTLBuffer, offset: Int, instanceStride: Int) {
        renderEncoder.setTessellationFactorBuffer(
            buffer,
            offset: offset,
            instanceStride: instanceStride
        )
    }

    func drawPatches(
        numberOfPatchControlPoints: Int,
        patchStart: Int,
        patchCount: Int,
        patchIndexBuffer: MTLBuffer?,
        patchIndexBufferOffset: Int,
        instanceCount: Int,
        baseInstance: Int
    ) {
        renderEncoder.drawPatches(
            numberOfPatchControlPoints: numberOfPatchControlPoints,
            patchStart: patchStart,
            patchCount: patchCount,
            patchIndexBuffer: patchIndexBuffer,
            patchIndexBufferOffset: patchIndexBufferOffset,
            instanceCount: instanceCount,
            baseInstance: baseInstance
        )
    }

    func drawIndexedPatches(
        numberOfPatchControlPoints: Int,
        patchStart: Int,
        patchCount: Int,
        patchIndexBuffer: MTLBuffer?,
        patchIndexBufferOffset: Int,
        controlPointIndexBuffer: MTLBuffer,
        controlPointIndexBufferOffset: Int,
        instanceCount: Int,
        baseInstance: Int
    ) {
        renderEncoder.drawIndexedPatches(
            numberOfPatchControlPoints: numberOfPatchControlPoints,
            patchStart: patchStart,
            patchCount: patchCount,
            patchIndexBuffer: patchIndexBuffer,
            patchIndexBufferOffset: patchIndexBufferOffset,
            controlPointIndexBuffer: controlPointIndexBuffer,
            controlPointIndexBufferOffset: controlPointIndexBufferOffset,
            instanceCount: instanceCount,
            baseInstance: baseInstance
        )
    }
}

@available(macOS 26.0, iOS 26.0, visionOS 26.0, *)
internal final class Metal4RenderCommandEncoder: SatinRenderCommandEncoder {
    private let renderEncoder: any MTL4RenderCommandEncoder
    private let argumentTables: Metal4ArgumentTables

    let supportsTessellation = false

    init(renderEncoder: any MTL4RenderCommandEncoder, argumentTables: Metal4ArgumentTables) {
        self.renderEncoder = renderEncoder
        self.argumentTables = argumentTables
        argumentTables.bind(to: renderEncoder)
    }

    func setCullMode(_ cullMode: MTLCullMode) {
        renderEncoder.setCullMode(cullMode)
    }

    func setFrontFacing(_ windingOrder: MTLWinding) {
        renderEncoder.setFrontFacing(windingOrder)
    }

    func setTriangleFillMode(_ triangleFillMode: MTLTriangleFillMode) {
        renderEncoder.setTriangleFillMode(triangleFillMode)
    }

    func setRenderPipelineState(_ pipeline: MTLRenderPipelineState) {
        renderEncoder.setRenderPipelineState(pipeline)
    }

    func setDepthStencilState(_ depthStencilState: MTLDepthStencilState?) {
        renderEncoder.setDepthStencilState(depthStencilState)
    }

    func setDepthClipMode(_ depthClipMode: MTLDepthClipMode) {
        renderEncoder.setDepthClipMode(depthClipMode)
    }

    func setDepthBias(_ depthBias: Float, slopeScale: Float, clamp: Float) {
        renderEncoder.setDepthBias(depthBias, slopeScale: slopeScale, clamp: clamp)
    }

    func setVertexBuffer(_ buffer: MTLBuffer, offset: Int, index: Int) {
        guard let vertexBufferIndex = VertexBufferIndex(rawValue: index) else { return }
        argumentTables.setVertexBuffer(buffer, offset: offset, index: vertexBufferIndex)
    }

    func setFragmentBuffer(_ buffer: MTLBuffer, offset: Int, index: Int) {
        guard let fragmentBufferIndex = FragmentBufferIndex(rawValue: index) else { return }
        argumentTables.setFragmentBuffer(buffer, offset: offset, index: fragmentBufferIndex)
    }

    func setVertexTexture(_ texture: MTLTexture?, index: Int) {
        guard let vertexTextureIndex = VertexTextureIndex(rawValue: index) else { return }
        argumentTables.setVertexTexture(texture, index: vertexTextureIndex)
    }

    func setFragmentTexture(_ texture: MTLTexture?, index: Int) {
        guard let fragmentTextureIndex = FragmentTextureIndex(rawValue: index) else { return }
        argumentTables.setFragmentTexture(texture, index: fragmentTextureIndex)
    }

    func setFragmentSamplerState(_ samplerState: MTLSamplerState?, index: Int) {
        guard let fragmentSamplerIndex = FragmentSamplerIndex(rawValue: index) else { return }
        argumentTables.setFragmentSamplerState(samplerState, index: fragmentSamplerIndex)
    }

    func drawPrimitives(type: MTLPrimitiveType, vertexStart: Int, vertexCount: Int, instanceCount: Int) {
        renderEncoder.drawPrimitives(
            primitiveType: type,
            vertexStart: vertexStart,
            vertexCount: vertexCount,
            instanceCount: instanceCount
        )
    }

    func drawIndexedPrimitives(
        type: MTLPrimitiveType,
        indexCount: Int,
        indexType: MTLIndexType,
        indexBuffer: MTLBuffer,
        indexBufferOffset: Int,
        instanceCount: Int
    ) {
        renderEncoder.drawIndexedPrimitives(
            primitiveType: type,
            indexCount: indexCount,
            indexType: indexType,
            indexBuffer: indexBuffer.gpuAddress + MTLGPUAddress(indexBufferOffset),
            indexBufferLength: Self.indexBufferLength(indexBuffer: indexBuffer, offset: indexBufferOffset),
            instanceCount: instanceCount
        )
    }

    static func indexBufferLength(indexBuffer: MTLBuffer, offset: Int) -> Int {
        max(0, indexBuffer.length - offset)
    }

    func setTessellationFactorBuffer(_ buffer: MTLBuffer, offset: Int, instanceStride: Int) {}

    func drawPatches(
        numberOfPatchControlPoints: Int,
        patchStart: Int,
        patchCount: Int,
        patchIndexBuffer: MTLBuffer?,
        patchIndexBufferOffset: Int,
        instanceCount: Int,
        baseInstance: Int
    ) {}

    func drawIndexedPatches(
        numberOfPatchControlPoints: Int,
        patchStart: Int,
        patchCount: Int,
        patchIndexBuffer: MTLBuffer?,
        patchIndexBufferOffset: Int,
        controlPointIndexBuffer: MTLBuffer,
        controlPointIndexBufferOffset: Int,
        instanceCount: Int,
        baseInstance: Int
    ) {}
}
