//
//  DiffuseIBLGenerator.swift
//  Satin
//
//  Created by Reza Ali on 11/8/22.
//  Copyright © 2022 Reza Ali. All rights reserved.
//

import Foundation
import Metal

public final class DiffuseIBLGenerator {
    final class DiffuseIBLComputeProcessor: TextureComputeProcessor {
        init(device: MTLDevice) {
            super.init(
                device: device,
                pipelinesURL: getPipelinesComputeURL()!
            )
        }
    }

    private var compute: DiffuseIBLComputeProcessor

    public init(device: MTLDevice) {
        compute = DiffuseIBLComputeProcessor(device: device)
    }

    public func encode(commandEncoder: MTLComputeCommandEncoder, sourceTexture: MTLTexture, destinationTexture: MTLTexture) {
        let iterations = _encode(sourceTexture: sourceTexture, destinationTexture: destinationTexture)
        compute.update(commandEncoder, iterations: iterations)
    }

    public func encode(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destinationTexture: MTLTexture) {
        let iterations = _encode(sourceTexture: sourceTexture, destinationTexture: destinationTexture)
        compute.update(commandBuffer, iterations: iterations)
    }

    public func encode(frameCommand: any SatinFrameCommand, sourceTexture: MTLTexture, destinationTexture: MTLTexture) {
        let iterations = _encode(sourceTexture: sourceTexture, destinationTexture: destinationTexture)
        compute.update(frameCommand, iterations: iterations)
    }

    private func _encode(sourceTexture: MTLTexture, destinationTexture: MTLTexture) -> Int {
        compute.set(destinationTexture, index: ComputeTextureIndex.Custom0) // output
        compute.set(sourceTexture, index: ComputeTextureIndex.Custom1) // input

        let faceBuffer = destinationTexture.device.makeBuffer(length: MemoryLayout<UInt32>.stride, options: .storageModeShared)

        compute.preCompute = { computeEncoder, iteration in
            var face = UInt32(iteration)
            computeEncoder.setBytes(&face, length: MemoryLayout<UInt32>.size, index: ComputeBufferIndex.Custom0.rawValue)
        }

        if #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) {
            compute.preComputeMetal4 = { (argumentTable: Metal4ComputeArgumentTable, iteration: Int) in
                guard let faceBuffer else { return }
                var face = UInt32(iteration)
                withUnsafeBytes(of: &face) { bytes in
                    if let baseAddress = bytes.baseAddress {
                        faceBuffer.contents().copyMemory(from: baseAddress, byteCount: bytes.count)
                    }
                }
                argumentTable.setBuffer(faceBuffer, offset: 0, index: ComputeBufferIndex.Custom0)
            }
        }

        destinationTexture.label = "Diffuse IBL"

        return 6
    }
}
