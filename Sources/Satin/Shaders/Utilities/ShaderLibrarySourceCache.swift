//
//  ShaderLibrarySourceCache.swift
//
//
//  Created by Reza Ali on 6/14/23.
//

import Foundation

// MARK: - Custom Injection Protocol
public protocol CustomShaderInjector {
    func injectCustomCode(source: inout String, configuration: ShaderLibraryConfiguration)
}

public final class ShaderLibrarySourceCache: Sendable {
    private nonisolated(unsafe) static var cache: [ShaderLibraryConfiguration: String] = [:]

    private static let queue = DispatchQueue(label: "ShaderLibrarySourceCacheQueue", attributes: .concurrent)

    // MARK: - Custom injector registry
    private nonisolated(unsafe) static var customInjectors: [String: CustomShaderInjector] = [:]
    private static let injectorsQueue = DispatchQueue(label: "ShaderLibrarySourceCacheInjectorsQueue", attributes: .concurrent)
    
    // MARK: - Register custom injector
    public static func registerCustomInjector(_ injector: CustomShaderInjector, for materialType: String) {
        injectorsQueue.sync(flags: .barrier) {
            customInjectors[materialType] = injector
        }
    }
    
    // MARK: - Unregister custom injector
    public static func unregisterCustomInjector(for materialType: String) {
        injectorsQueue.sync(flags: .barrier) {
            customInjectors.removeValue(forKey: materialType)
        }
    }

    static func invalidateLibrarySource(configuration: ShaderLibraryConfiguration) {
        queue.sync(flags: .barrier) {
            _ = cache.removeValue(forKey: configuration)
        }
    }

    static func getLibrarySource(configuration: ShaderLibraryConfiguration) throws -> String? {
        var cachedSource: String?

        queue.sync {
            cachedSource = cache[configuration]
        }

        if let cachedSource {
//            print("Returning Cached Shader Library Source: \n\(configuration)")
            return cachedSource
        }

//        print("Creating Shader Library Source: \(configuration)")

        guard let pipelineURL = configuration.pipelineURL,
              var source = RenderIncludeSource.get(),
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

        injectShadowData(
            source: &source,
            receiveShadow: configuration.receiveShadow,
            shadowCount: configuration.shadowCount
        )

//      injectParametersArgs(
//            source: &source,
//            instancing: configuration.parameters
//        )

        injectShadowBuffer(
            source: &source,
            receiveShadow: configuration.receiveShadow,
            shadowCount: configuration.shadowCount
        )

        injectShadowFunction(
            source: &source,
            receiveShadow: configuration.receiveShadow,
            shadowCount: configuration.shadowCount
        )

        injectVertex(
            source: &source,
            vertexDescriptor: configuration.vertexDescriptor
        )

        source += shaderSource

        injectPassThroughVertex(
            label: configuration.label,
            source: &source
        )

        if configuration.castShadow {
            injectPassThroughShadowVertex(
                label: configuration.label,
                source: &source
            )
        }

        injectInstancingArgs(
            source: &source,
            instancing: configuration.instancing
        )

//      injectUniformParametersArgs(
//            source: &source,
//            instancing: configuration.parameters
//        )

        injectShadowCoords(
            source: &source,
            receiveShadow: configuration.receiveShadow,
            shadowCount: configuration.shadowCount
        )

        injectShadowVertexArgs(
            source: &source,
            receiveShadow: configuration.receiveShadow
        )

        injectShadowVertexCalc(
            source: &source,
            receiveShadow: configuration.receiveShadow,
            shadowCount: configuration.shadowCount
        )

        injectShadowFragmentArgs(
            source: &source,
            receiveShadow: configuration.receiveShadow,
            shadowCount: configuration.shadowCount
        )

        injectShadowFragmentCalc(
            source: &source,
            receiveShadow: configuration.receiveShadow,
            shadowCount: configuration.shadowCount
        )

        injectLightingArgs(
            source: &source,
            lighting: configuration.lighting
        )

        injectCustomCode(source: &source, configuration: configuration)
        
        queue.sync(flags: .barrier) {
            cache[configuration] = source
        }

//        print(source)

        return source
    }

    // MARK: Custom injection method
    private static func injectCustomCode(source: inout String, configuration: ShaderLibraryConfiguration) {
        var availableInjectors: [String: CustomShaderInjector] = [:]
        
        injectorsQueue.sync {
            availableInjectors = customInjectors
        }
        
        if let injector = availableInjectors[configuration.label] {
            injector.injectCustomCode(source: &source, configuration: configuration)
        }
        
        if let globalInjector = availableInjectors["*"] {
            globalInjector.injectCustomCode(source: &source, configuration: configuration)
        }
    }
}
