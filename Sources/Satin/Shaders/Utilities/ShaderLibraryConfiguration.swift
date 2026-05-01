//
//  ShaderLibraryConfiguration.swift
//
//
//  Created by Reza Ali on 6/14/23.
//

import Foundation
import Metal

// these are things that change the library source code
public struct ShaderLibraryConfiguration {
    var contextID: UUID?
    var deviceID: ObjectIdentifier?
    var label: String

    var libraryURL: URL?
    var pipelineURL: URL?

    var vertexDescriptor: MTLVertexDescriptor

    // Instancing
    var instancing: Bool

    // Lighting
    var lighting: Bool

    // Shadows
    var castShadow: Bool
    var receiveShadow: Bool
    var directShadowCount: Int
    var directShadowTextureCount: Int

    var defines: [ShaderDefine]
    var constants: [String]

    // Custom source transforms — applied at end of source generation.
    // The array itself is excluded from hash/equality; `sourceTransformIdentity`
    // is a per-shader nonce that participates in the cache key. `nil` means no
    // transforms (so configs without transforms hit the global cache freely);
    // otherwise it disambiguates configs that are otherwise identical but have
    // different transform sets.
    var sourceTransforms: [ShaderSourceTransform] = []
    var sourceTransformIdentity: UUID? = nil
}

extension ShaderLibraryConfiguration: Equatable {
    public static func == (lhs: ShaderLibraryConfiguration, rhs: ShaderLibraryConfiguration) -> Bool {
        lhs.contextID == rhs.contextID &&
            lhs.deviceID == rhs.deviceID &&
            lhs.label == rhs.label &&
            lhs.libraryURL == rhs.libraryURL &&
            lhs.pipelineURL == rhs.pipelineURL &&
            lhs.vertexDescriptor == rhs.vertexDescriptor &&
            lhs.instancing == rhs.instancing &&
            lhs.lighting == rhs.lighting &&
            lhs.castShadow == rhs.castShadow &&
            lhs.receiveShadow == rhs.receiveShadow &&
            lhs.directShadowCount == rhs.directShadowCount &&
            lhs.directShadowTextureCount == rhs.directShadowTextureCount &&
            lhs.defines == rhs.defines &&
            lhs.constants == rhs.constants &&
            lhs.sourceTransformIdentity == rhs.sourceTransformIdentity
    }
}

extension ShaderLibraryConfiguration: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(contextID)
        hasher.combine(deviceID)
        hasher.combine(label)

        if let libraryURL = libraryURL { hasher.combine(libraryURL) }
        if let pipelineURL = pipelineURL { hasher.combine(pipelineURL) }

        hasher.combine(vertexDescriptor)
        hasher.combine(instancing)
        hasher.combine(lighting)

        hasher.combine(castShadow)
        hasher.combine(receiveShadow)
        hasher.combine(directShadowCount)
        hasher.combine(directShadowTextureCount)

        if !defines.isEmpty { hasher.combine(defines) }
        if !constants.isEmpty { hasher.combine(constants) }
        if let sourceTransformIdentity { hasher.combine(sourceTransformIdentity) }
    }
}
