//
//  ComputeShaderLibrarySourceCache.swift
//
//
//  Created by Reza Ali on 1/8/24.
//

import Foundation

public final class ComputeShaderLibrarySourceCache: Sendable {
    private nonisolated(unsafe) static var cache: [ComputeShaderLibraryConfiguration: String] = [:]
    private static let queue = DispatchQueue(label: "ComputeShaderLibrarySourceCacheQueue", attributes: .concurrent)

    static func invalidateLibrarySource(configuration: ComputeShaderLibraryConfiguration) {
        queue.sync(flags: .barrier) {
            _ = cache.removeValue(forKey: configuration)
        }
    }

    static func getLibrarySource(configuration: ComputeShaderLibraryConfiguration) throws -> String? {
        var cachedSource: String?

        queue.sync {
            cachedSource = ComputeShaderLibrarySourceCache.cache[configuration]
        }

        if let cachedSource {
            return cachedSource
        }

//        print("Creating Compute Shader Library Source: \(configuration.label)")

        guard let pipelineURL = configuration.pipelineURL,
              var source = ComputeIncludeSource.get(),
              let shaderSource = try ShaderSourceCache.getSource(url: pipelineURL)
        else { return nil }

        injectDefines(
            source: &source,
            defines: configuration.defines
        )

        injectConstants(
            source: &source,
            constants: configuration.constants
        )

        source += shaderSource

        for transform in configuration.sourceTransforms {
            transform.transform(source: &source, configuration: configuration)
        }

        queue.sync(flags: .barrier) {
            cache[configuration] = source
        }

        return source
    }
}
