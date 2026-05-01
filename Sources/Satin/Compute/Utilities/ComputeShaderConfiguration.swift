//
//  ComputeShaderConfiguration.swift
//
//
//  Created by Reza Ali on 1/8/24.
//

import Foundation
import Metal

public struct ComputeShaderConfiguration {
    public internal(set) var device: MTLDevice?

    // Information
    public internal(set) var label: String

    public internal(set) var resetFunctionName: String
    public internal(set) var updateFunctionName: String

    // URLs
    public internal(set) var libraryURL: URL? // this is where we get the MTLLibrary from file and build from there
    public internal(set) var pipelineURL: URL? // this is where we get the pipeline source from file and build from there

    public internal(set) var compute = ComputeConfiguration()

    // Custom source transforms (excluded from hash/eq; identity drives invalidation).
    public internal(set) var sourceTransforms: [ComputeShaderSourceTransform] = []
    public internal(set) var sourceTransformIdentity: UUID? = nil

    public init(
        label: String = "",
        resetFunctionName: String = "",
        updateFunctionName: String = "",
        libraryURL: URL? = nil,
        pipelineURL: URL? = nil
    ) {
        self.label = label
        self.resetFunctionName = resetFunctionName
        self.updateFunctionName = updateFunctionName
        self.libraryURL = libraryURL
        self.pipelineURL = pipelineURL
    }

    public func getLibraryConfiguration() -> ComputeShaderLibraryConfiguration {
        ComputeShaderLibraryConfiguration(
            label: label,
            libraryURL: libraryURL,
            pipelineURL: pipelineURL,
            defines: compute.getDefines(),
            constants: compute.getConstants(),
            sourceTransforms: sourceTransforms,
            sourceTransformIdentity: sourceTransformIdentity
        )
    }
}

extension ComputeShaderConfiguration: Equatable {
    public static func == (lhs: ComputeShaderConfiguration, rhs: ComputeShaderConfiguration) -> Bool {
        lhs.device === rhs.device &&
            lhs.label == rhs.label &&
            lhs.resetFunctionName == rhs.resetFunctionName &&
            lhs.updateFunctionName == rhs.updateFunctionName &&
            lhs.libraryURL == rhs.libraryURL &&
            lhs.pipelineURL == rhs.pipelineURL &&
            lhs.compute == rhs.compute &&
            lhs.sourceTransformIdentity == rhs.sourceTransformIdentity
    }
}

extension ComputeShaderConfiguration: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(label)

        if !resetFunctionName.isEmpty { hasher.combine(resetFunctionName) }
        if !updateFunctionName.isEmpty { hasher.combine(updateFunctionName) }

        if let libraryURL = libraryURL { hasher.combine(libraryURL) }
        if let pipelineURL = pipelineURL { hasher.combine(pipelineURL) }

        hasher.combine(compute)
        if let sourceTransformIdentity { hasher.combine(sourceTransformIdentity) }
    }
}

extension ComputeShaderConfiguration: CustomStringConvertible {
    public var description: String {
        var output = "\n"
        output += "\t Label: \(label)\n"
        output += "\t ResetFunctionName: \(resetFunctionName)\n"
        output += "\t UpdateFunctionName: \(updateFunctionName)\n"
        if let libraryURL = libraryURL { output += "\t libraryURL: \(libraryURL.relativePath)\n" }
        if let pipelineURL = pipelineURL { output += "\t pipelineURL: \(pipelineURL.relativePath)\n" }
        output += "\t \(compute.description)"
        return output
    }
}
