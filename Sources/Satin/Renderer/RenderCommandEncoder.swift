//
//  RenderCommandEncoder.swift
//  Satin
//
//  Internal render command interface for backend-specific encoder state.
//

import Metal

internal protocol SatinRenderCommandEncoder {
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
    func drawPrimitives(type: MTLPrimitiveType, vertexStart: Int, vertexCount: Int, instanceCount: Int)
    func drawIndexedPrimitives(
        type: MTLPrimitiveType,
        indexCount: Int,
        indexType: MTLIndexType,
        indexBuffer: MTLBuffer,
        indexBufferOffset: Int,
        instanceCount: Int
    )
}

internal final class MetalRenderCommandEncoder: SatinRenderCommandEncoder {
    private let renderEncoder: MTLRenderCommandEncoder

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
}
