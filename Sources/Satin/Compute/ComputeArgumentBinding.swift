//
//  ComputeArgumentBinding.swift
//  Satin
//
//  Backend-neutral compute argument binding surface.
//

import Metal

public protocol ComputeArgumentBinding: AnyObject {
    var backend: MetalBackend { get }

    @discardableResult
    func setBuffer(_ buffer: MTLBuffer, offset: Int, index: ComputeBufferIndex) -> Bool

    @discardableResult
    func setBuffer(_ buffer: MTLBuffer, offset: Int, index: Int) -> Bool

    @discardableResult
    func setTexture(_ texture: MTLTexture?, index: ComputeTextureIndex) -> Bool

    @discardableResult
    func setTexture(_ texture: MTLTexture?, index: Int) -> Bool
}

internal final class MetalComputeArgumentBinding: ComputeArgumentBinding {
    let backend: MetalBackend = .metal3
    private let computeEncoder: MTLComputeCommandEncoder

    init(_ computeEncoder: MTLComputeCommandEncoder) {
        self.computeEncoder = computeEncoder
    }

    @discardableResult
    func setBuffer(_ buffer: MTLBuffer, offset: Int, index: ComputeBufferIndex) -> Bool {
        setBuffer(buffer, offset: offset, index: index.rawValue)
    }

    @discardableResult
    func setBuffer(_ buffer: MTLBuffer, offset: Int, index: Int) -> Bool {
        computeEncoder.setBuffer(buffer, offset: offset, index: index)
        return true
    }

    @discardableResult
    func setTexture(_ texture: MTLTexture?, index: ComputeTextureIndex) -> Bool {
        setTexture(texture, index: index.rawValue)
    }

    @discardableResult
    func setTexture(_ texture: MTLTexture?, index: Int) -> Bool {
        computeEncoder.setTexture(texture, index: index)
        return true
    }
}

@available(macOS 26.0, iOS 26.0, visionOS 26.0, *)
internal final class Metal4ComputeArgumentBinding: ComputeArgumentBinding {
    let backend: MetalBackend = .metal4
    private let argumentTable: Metal4ComputeArgumentTable

    init(_ argumentTable: Metal4ComputeArgumentTable) {
        self.argumentTable = argumentTable
    }

    @discardableResult
    func setBuffer(_ buffer: MTLBuffer, offset: Int, index: ComputeBufferIndex) -> Bool {
        argumentTable.setBuffer(buffer, offset: offset, index: index)
    }

    @discardableResult
    func setBuffer(_ buffer: MTLBuffer, offset: Int, index: Int) -> Bool {
        argumentTable.setBuffer(buffer, offset: offset, index: index)
    }

    @discardableResult
    func setTexture(_ texture: MTLTexture?, index: ComputeTextureIndex) -> Bool {
        argumentTable.setTexture(texture, index: index)
    }

    @discardableResult
    func setTexture(_ texture: MTLTexture?, index: Int) -> Bool {
        argumentTable.setTexture(texture, index: index)
    }
}
