//
//  RenderEncoderState.swift
//
//
//  Created by Reza Ali on 12/12/23.
//

import Foundation
import Metal

public final class RenderEncoderState {
    public let renderEncoder: MTLRenderCommandEncoder
    private let commands: SatinRenderCommandEncoder

    public var cullMode: MTLCullMode? {
        didSet {
            if oldValue != cullMode, let cullMode {
                commands.setCullMode(cullMode)
            }
        }
    }

    public var windingOrder: MTLWinding? {
        didSet {
            if oldValue != windingOrder, let windingOrder {
                commands.setFrontFacing(windingOrder)
            }
        }
    }

    public var triangleFillMode: MTLTriangleFillMode? {
        didSet {
            if oldValue != triangleFillMode, let triangleFillMode {
                commands.setTriangleFillMode(triangleFillMode)
            }
        }
    }

    public var pipeline: MTLRenderPipelineState? {
        didSet {
            if oldValue !== pipeline, let pipeline {
                commands.setRenderPipelineState(pipeline)
            }
        }
    }

    public var depthStencilState: MTLDepthStencilState? {
        didSet {
            if oldValue !== depthStencilState {
                commands.setDepthStencilState(depthStencilState)
            }
        }
    }

    public var depthClipMode: MTLDepthClipMode? {
        didSet {
            if oldValue != depthClipMode, let depthClipMode {
                #if !targetEnvironment(simulator)
                commands.setDepthClipMode(depthClipMode)
                #endif
            }
        }
    }

    public var depthBias: DepthBias? {
        didSet {
            if oldValue != depthBias {
                if let depthBias = depthBias {
                    commands.setDepthBias(depthBias.bias, slopeScale: depthBias.slope, clamp: depthBias.clamp)
                }
                else {
                    commands.setDepthBias(0.0, slopeScale: 0.0, clamp: 0.0)
                }
            }
        }
    }

    public var vertexVertexUniforms: VertexUniformBuffer? {
        didSet {
            if oldValue !== vertexVertexUniforms, let vertexVertexUniforms {
                commands.setVertexBuffer(
                    vertexVertexUniforms.buffer,
                    offset: vertexVertexUniforms.offset,
                    index: VertexBufferIndex.VertexUniforms.rawValue
                )
            }
        }
    }

    public var fragmentVertexUniforms: VertexUniformBuffer? {
        didSet {
            if oldValue !== fragmentVertexUniforms, let fragmentVertexUniforms {
                commands.setFragmentBuffer(
                    fragmentVertexUniforms.buffer,
                    offset: fragmentVertexUniforms.offset,
                    index: FragmentBufferIndex.VertexUniforms.rawValue
                )
            }
        }
    }

    public var vertexMaterialUniforms: UniformBuffer? {
        didSet {
            if oldValue !== vertexMaterialUniforms, let vertexMaterialUniforms {
                commands.setVertexBuffer(
                    vertexMaterialUniforms.buffer,
                    offset: vertexMaterialUniforms.offset,
                    index: VertexBufferIndex.MaterialUniforms.rawValue
                )
            }
        }
    }

    public var vertexInstanceUniforms: InstanceMatrixUniformBuffer? {
        didSet {
            if oldValue !== vertexInstanceUniforms, let vertexInstanceUniforms {
                commands.setVertexBuffer(
                    vertexInstanceUniforms.buffer,
                    offset: vertexInstanceUniforms.offset,
                    index: VertexBufferIndex.InstanceMatrixUniforms.rawValue
                )
            }
        }
    }

    public var fragmentMaterialUniforms: UniformBuffer? {
        didSet {
            if oldValue !== fragmentMaterialUniforms, let fragmentMaterialUniforms {
                commands.setFragmentBuffer(
                    fragmentMaterialUniforms.buffer,
                    offset: fragmentMaterialUniforms.offset,
                    index: FragmentBufferIndex.MaterialUniforms.rawValue
                )
            }
        }
    }

    private var vertexBuffers = [VertexBufferIndex: MTLBuffer]()
    private var vertexTextures = [VertexTextureIndex: MTLTexture?]()

    private var fragmentBuffers = [FragmentBufferIndex: MTLBuffer]()
    private var fragmentPBRTextures = [PBRTextureType: MTLTexture?]()
    private var fragmentTextures = [FragmentTextureIndex: MTLTexture?]()

    public func setVertexBuffer(_ buffer: MTLBuffer, offset: Int, index: VertexBufferIndex) {
        if let existingBuffer = vertexBuffers[index], existingBuffer === buffer {
            return
        }
        else {
            commands.setVertexBuffer(buffer, offset: offset, index: index.rawValue)
            vertexBuffers[index] = buffer
        }
    }

    public func setFragmentBuffer(_ buffer: MTLBuffer, offset: Int, index: FragmentBufferIndex) {
        if let existingBuffer = fragmentBuffers[index], existingBuffer === buffer {
            return
        }
        else {
            commands.setFragmentBuffer(buffer, offset: offset, index: index.rawValue)
            fragmentBuffers[index] = buffer
        }
    }

    public func setFragmentPBRTexture(_ texture: MTLTexture?, type: PBRTextureType) {
        if let existingTexture = fragmentPBRTextures[type], existingTexture === texture {
            return
        }
        else {
            commands.setFragmentTexture(texture, index: type.index)
            fragmentPBRTextures[type] = texture
        }
    }

    public func setVertexTexture(_ texture: MTLTexture?, index: VertexTextureIndex) {
        if let existingTexture = vertexTextures[index], existingTexture === texture {
            return
        }
        else {
            commands.setVertexTexture(texture, index: index.rawValue)
            vertexTextures[index] = texture
        }
    }

    public func setFragmentTexture(_ texture: MTLTexture?, index: FragmentTextureIndex) {
        if let existingTexture = fragmentTextures[index], existingTexture === texture {
            return
        }
        else {
            commands.setFragmentTexture(texture, index: index.rawValue)
            fragmentTextures[index] = texture
        }
    }

    init(renderEncoder: MTLRenderCommandEncoder) {
        self.renderEncoder = renderEncoder
        self.commands = MetalRenderCommandEncoder(renderEncoder: renderEncoder)
    }
}
