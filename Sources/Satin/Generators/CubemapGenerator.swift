//
//  CubemapGenerator.swift
//  Satin
//
//  Created by Reza Ali on 11/8/22.
//  Copyright © 2022 Reza Ali. All rights reserved.
//

import Foundation
import Metal
import MetalPerformanceShaders

public final class CubemapGenerator {
    final class CubemapProcessor: TextureComputeProcessor {
        init(device: MTLDevice) {
            super.init(device: device, pipelinesURL: getPipelinesComputeURL()!)
        }
    }

    private var compute: CubemapProcessor
    private var blur: MPSImageGaussianBlur?

    public init(device: MTLDevice, sigma: Float = 0.0, tonemapped: Bool = false, gammaCorrected: Bool = false) {
        compute = CubemapProcessor(device: device)
        if sigma > 0.0 {
            blur = MPSImageGaussianBlur(device: device, sigma: sigma)
            blur?.edgeMode = .clamp
        }
        compute.set("Tone Mapped", tonemapped)
        compute.set("Gamma Corrected", gammaCorrected)
    }

    public func encode(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destinationTexture: MTLTexture) {
        var finalSourceTexture = sourceTexture

        if let blur {
            let descriptor = MTLTextureDescriptor()
            descriptor.pixelFormat = sourceTexture.pixelFormat
            descriptor.width = sourceTexture.width
            descriptor.height = sourceTexture.height
            descriptor.textureType = sourceTexture.textureType
            descriptor.sampleCount = 1
            descriptor.usage = [.shaderRead, .shaderWrite]
            descriptor.storageMode = .private
            descriptor.resourceOptions = .storageModePrivate
            descriptor.allowGPUOptimizedContents = true

            if let sourceTextureBlurred = commandBuffer.device.makeTexture(descriptor: descriptor) {
                blur.encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture, destinationTexture: sourceTextureBlurred)
                finalSourceTexture = sourceTextureBlurred
            }
        }

        compute.set(destinationTexture, index: ComputeTextureIndex.Custom0) // output
        compute.set(finalSourceTexture, index: ComputeTextureIndex.Custom1) // input
        compute.update(commandBuffer)

        if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
            blitEncoder.generateMipmaps(for: destinationTexture)
            blitEncoder.endEncoding()
        }

        destinationTexture.label = "Cubemap"
    }

    @discardableResult
    public func encode(frameCommand: any SatinFrameCommand, sourceTexture: MTLTexture, destinationTexture: MTLTexture) -> Bool {
        guard blur == nil else { return false }

        compute.set(destinationTexture, index: ComputeTextureIndex.Custom0) // output
        compute.set(sourceTexture, index: ComputeTextureIndex.Custom1) // input
        guard compute.update(frameCommand) else { return false }

        if destinationTexture.mipmapLevelCount > 1 {
            if let frameCommand = frameCommand as? MetalFrameCommand,
               let blitEncoder = frameCommand.commandBuffer.makeBlitCommandEncoder() {
                blitEncoder.generateMipmaps(for: destinationTexture)
                blitEncoder.endEncoding()
            } else if #available(macOS 26.0, iOS 26.0, visionOS 26.0, *),
                      let frameCommand = frameCommand as? Metal4FrameCommand,
                      let computeEncoder = frameCommand.commandBuffer.makeComputeCommandEncoder() {
                computeEncoder.generateMipmaps(texture: destinationTexture)
                computeEncoder.endEncoding()
            }
        }

        destinationTexture.label = "Cubemap"
        return true
    }
}
