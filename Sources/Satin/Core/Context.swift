//
//  Context.swift
//  Satin
//
//  Created by Reza Ali on 9/25/19.
//  Copyright © 2019 Reza Ali. All rights reserved.
//

import Metal

public enum MetalBackend: Hashable, Sendable {
    case metal3
    case metal4
}

public struct Context {
    public let id: UUID
    public let device: MTLDevice
    public let commandQueue:MTLCommandQueue
    public let requestedBackend: MetalBackend
    public let backend: MetalBackend
    public let sampleCount: Int
    public let colorPixelFormat: MTLPixelFormat
    public let depthPixelFormat: MTLPixelFormat
    public let stencilPixelFormat: MTLPixelFormat
    public let vertexAmplificationCount: Int
    public let maxBuffersInFlight: Int

    // Rendering mode and active auxiliary outputs. Switching renderingMode at runtime causes
    // pipeline states to recompile on the next frame — avoid toggling per-frame.
    public let renderingMode: RenderingMode
    public let activeOutputs: RendererOutputs
    public let alphaOitEnabled: Bool

    // Pixel formats for each auxiliary G-buffer attachment. These must match the formats used
    // when creating the corresponding textures on the renderer — both the pipeline descriptor
    // (compiled from Context) and the render pass descriptor (texture creation) read from here.
    public let albedoPixelFormat: MTLPixelFormat
    public let normalsPixelFormat: MTLPixelFormat
    public let pbrPixelFormat: MTLPixelFormat
    public let velocityPixelFormat: MTLPixelFormat
    public let emissivePixelFormat: MTLPixelFormat

    private let metal4SupportStorage: Any?

    public init(
        id: UUID = UUID(),
        device: MTLDevice,
        backend requestedBackend: MetalBackend = .metal3,
        sampleCount: Int,
        colorPixelFormat: MTLPixelFormat,
        depthPixelFormat: MTLPixelFormat = .invalid,
        stencilPixelFormat: MTLPixelFormat = .invalid,
        vertexAmplificationCount: Int = 1,
        maxBuffersInFlight: Int = Satin.maxBuffersInFlight,
        renderingMode: RenderingMode = .forward,
        activeOutputs: RendererOutputs = [.color],
        alphaOitEnabled: Bool = false,
        albedoPixelFormat: MTLPixelFormat = .bgra8Unorm,
        normalsPixelFormat: MTLPixelFormat = .rgba16Float,
        pbrPixelFormat: MTLPixelFormat = .rgba8Unorm,
        velocityPixelFormat: MTLPixelFormat = .rg16Float,
        emissivePixelFormat: MTLPixelFormat = .rgba16Float,
        // Optional pre-existing MTL4 command queue — pass the compositor's queue
        // from cp_layer_renderer_get_mtl4_command_queue when integrating with the
        // visionOS spatial compositor. Erased to Any? to keep this initializer
        // available on pre-OS-26 callers. Ignored unless requestedBackend == .metal4.
        externalMetal4CommandQueue: Any? = nil
    ) {
        self.id = id
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.requestedBackend = requestedBackend
        self.metal4SupportStorage = Self.makeMetal4Support(
            device: device,
            requestedBackend: requestedBackend,
            maxBuffersInFlight: maxBuffersInFlight,
            externalCommandQueue: externalMetal4CommandQueue
        )
        self.backend = metal4SupportStorage == nil ? .metal3 : requestedBackend
        self.sampleCount = sampleCount
        self.colorPixelFormat = colorPixelFormat
        self.depthPixelFormat = depthPixelFormat
        self.stencilPixelFormat = stencilPixelFormat
        self.vertexAmplificationCount = vertexAmplificationCount
        self.maxBuffersInFlight = maxBuffersInFlight
        self.renderingMode = renderingMode
        self.activeOutputs = activeOutputs
        self.alphaOitEnabled = alphaOitEnabled
        self.albedoPixelFormat = albedoPixelFormat
        self.normalsPixelFormat = normalsPixelFormat
        self.pbrPixelFormat = pbrPixelFormat
        self.velocityPixelFormat = velocityPixelFormat
        self.emissivePixelFormat = emissivePixelFormat
    }

    private static func makeMetal4Support(
        device: MTLDevice,
        requestedBackend: MetalBackend,
        maxBuffersInFlight: Int,
        externalCommandQueue: Any?
    ) -> Any? {
        guard requestedBackend == .metal4 else { return nil }

        if #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) {
            // Metal 4 features (argument tables, command allocators, residency sets)
            // require MTLGPUFamily.metal4 — Apple7+ silicon, no Intel / AMD.
            // See Reference/Documentations/Metal-Feature-Set-Tables.pdf p.5.
            guard device.supportsFamily(.metal4) else { return nil }
            let typedQueue = externalCommandQueue as? (any MTL4CommandQueue)
            return Metal4Support(
                device: device,
                maxBuffersInFlight: maxBuffersInFlight,
                commandQueue: typedQueue
            )
        }

        return nil
    }

    func getDefines() -> [ShaderDefine] {
        var defines = [ShaderDefine]()
        if vertexAmplificationCount > 1 {
            defines.append(ShaderDefine(key: "LAYERED", value: NSString(string: "true")))
        }
        if activeOutputs.contains(.albedo)   { defines.append(ShaderDefine(key: "OUTPUT_ALBEDO",   value: NSString(string: "1"))) }
        if activeOutputs.contains(.normals)  { defines.append(ShaderDefine(key: "OUTPUT_NORMALS",  value: NSString(string: "1"))) }
        if activeOutputs.contains(.pbr)      { defines.append(ShaderDefine(key: "OUTPUT_PBR",      value: NSString(string: "1"))) }
        if activeOutputs.contains(.velocity) { defines.append(ShaderDefine(key: "OUTPUT_VELOCITY", value: NSString(string: "1"))) }
        if activeOutputs.contains(.emissive) { defines.append(ShaderDefine(key: "OUTPUT_EMISSIVE", value: NSString(string: "1"))) }
        if alphaOitEnabled {
            defines.append(ShaderDefine(key: "ALPHA_OIT", value: NSString(string: "1")))
        }
        switch renderingMode {
        case .deferredGeometry: defines.append(ShaderDefine(key: "DEFERRED_GEOMETRY", value: NSString(string: "1")))
        case .forwardPlus:      defines.append(ShaderDefine(key: "FORWARD_PLUS",      value: NSString(string: "1")))
        case .forward:          break
        }
        return defines
    }
}

@available(macOS 26.0, iOS 26.0, visionOS 26.0, *)
extension Context {
    internal var metal4Support: Metal4Support? {
        metal4SupportStorage as? Metal4Support
    }
}

extension Context: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(ObjectIdentifier(device))
        hasher.combine(requestedBackend)
        hasher.combine(backend)
        hasher.combine(sampleCount)
        hasher.combine(colorPixelFormat)
        hasher.combine(depthPixelFormat)
        hasher.combine(stencilPixelFormat)
        hasher.combine(vertexAmplificationCount)
        hasher.combine(maxBuffersInFlight)
        hasher.combine(renderingMode)
        hasher.combine(activeOutputs)
        hasher.combine(alphaOitEnabled)
        hasher.combine(albedoPixelFormat)
        hasher.combine(normalsPixelFormat)
        hasher.combine(pbrPixelFormat)
        hasher.combine(velocityPixelFormat)
        hasher.combine(emissivePixelFormat)
    }
}

extension Context: Equatable {
    public static func == (lhs: Context, rhs: Context) -> Bool {
        lhs.id == rhs.id &&
            lhs.device === rhs.device &&
            lhs.requestedBackend == rhs.requestedBackend &&
            lhs.backend == rhs.backend &&
            lhs.sampleCount == rhs.sampleCount &&
            lhs.colorPixelFormat == rhs.colorPixelFormat &&
            lhs.depthPixelFormat == rhs.depthPixelFormat &&
            lhs.stencilPixelFormat == rhs.stencilPixelFormat &&
            lhs.vertexAmplificationCount == rhs.vertexAmplificationCount &&
            lhs.maxBuffersInFlight == rhs.maxBuffersInFlight &&
            lhs.renderingMode == rhs.renderingMode &&
            lhs.activeOutputs == rhs.activeOutputs &&
            lhs.alphaOitEnabled == rhs.alphaOitEnabled &&
            lhs.albedoPixelFormat == rhs.albedoPixelFormat &&
            lhs.normalsPixelFormat == rhs.normalsPixelFormat &&
            lhs.pbrPixelFormat == rhs.pbrPixelFormat &&
            lhs.velocityPixelFormat == rhs.velocityPixelFormat &&
            lhs.emissivePixelFormat == rhs.emissivePixelFormat
    }
}

public extension Context {
    static func makePlatformDefault(device: MTLDevice? = nil, backend: MetalBackend = .metal3) -> Context {
        let device = device ?? MTLCreateSystemDefaultDevice()!
#if os(visionOS)
#if targetEnvironment(simulator)
        return Context(
            device: device,
            backend: backend,
            sampleCount: 1,
            colorPixelFormat: .bgra8Unorm_srgb,
            depthPixelFormat: .depth32Float,
            vertexAmplificationCount: 1
        )
#else
        return Context(
            device: device,
            backend: backend,
            sampleCount: 1,
            colorPixelFormat: .bgra8Unorm_srgb,
            depthPixelFormat: .depth32Float,
            vertexAmplificationCount: 2
        )
#endif
#else
        return Context(
            device: device,
            backend: backend,
            sampleCount: 1,
            colorPixelFormat: .bgra8Unorm,
            depthPixelFormat: .depth32Float
        )
#endif
    }
}

extension CodingUserInfoKey {
    public static let satinContext = CodingUserInfoKey(rawValue: "Satin.Context")!
}

extension Decoder {
    public var satinContext: Context? {
        userInfo[.satinContext] as? Context
    }

    public func requireSatinContext(typeName: String) throws -> Context {
        guard let context = satinContext else {
            let description = "\(typeName) decoding requires Decoder.userInfo[.satinContext]"
            throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: description))
        }
        return context
    }
}
