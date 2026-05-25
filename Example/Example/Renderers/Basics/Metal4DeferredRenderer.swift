//
//  Metal4DeferredRenderer.swift
//  Example
//
//  Deferred-geometry rendering on the Metal 4 frame-command backend. Exercises
//  the G-buffer (albedo/normals/PBR/emissive) auxiliary attachments + the
//  deferred lighting resolve pass under MTL4 argument tables.
//

import Metal
import MetalKit
import Satin

final class Metal4DeferredRenderer: BaseRenderer {
    lazy var metallicSphere = Mesh(
        context: defaultContext,
        label: "Metallic Sphere",
        geometry: IcoSphereGeometry(context: defaultContext, radius: 0.55, resolution: 3),
        material: StandardMaterial(
            context: defaultContext,
            baseColor: simd_float4(0.92, 0.28, 0.18, 1.0),
            metallic: 0.95,
            roughness: 0.18,
            specular: 1.0
        )
    )

    lazy var matteSphere = Mesh(
        context: defaultContext,
        label: "Matte Sphere",
        geometry: IcoSphereGeometry(context: defaultContext, radius: 0.55, resolution: 3),
        material: StandardMaterial(
            context: defaultContext,
            baseColor: simd_float4(0.22, 0.78, 0.30, 1.0),
            metallic: 0.02,
            roughness: 0.88,
            specular: 0.35
        )
    )

    lazy var brushedSphere = Mesh(
        context: defaultContext,
        label: "Brushed Sphere",
        geometry: IcoSphereGeometry(context: defaultContext, radius: 0.40, resolution: 3),
        material: StandardMaterial(
            context: defaultContext,
            baseColor: simd_float4(0.88, 0.82, 0.28, 1.0),
            metallic: 0.58,
            roughness: 0.58,
            specular: 0.78
        )
    )

    lazy var floor = Mesh(
        context: defaultContext,
        label: "Floor",
        geometry: PlaneGeometry(context: defaultContext, size: 6.0, orientation: .zx),
        material: BasicDiffuseMaterial(
            context: defaultContext,
            color: simd_float4(0.20, 0.22, 0.26, 1.0),
            blending: .disabled,
            hardness: 0.4
        )
    )

    lazy var directional = DirectionalLight(context: defaultContext, color: simd_float3(1.0, 0.97, 0.92), intensity: 1.6)
    lazy var fill = PointLight(context: defaultContext, color: simd_float3(0.25, 0.5, 0.95), intensity: 1.4, radius: 8.0)

    lazy var scene = Object(context: defaultContext, label: "Scene", [directional, fill, floor, metallicSphere, matteSphere, brushedSphere])
    lazy var renderer = RenderEncoder(context: defaultContext)
    lazy var camera = PerspectiveCamera(context: defaultContext, position: [0.0, 0.6, 5.5], near: 0.1, far: 100.0, fov: 32)
    lazy var cameraController = PerspectiveCameraController(camera: camera, view: metalView)
    lazy var startTime = getTime()

    init() {
        super.init(
            context: Context.makePlatformDefault(backend: .metal4).with(renderingMode: .deferredGeometry)
        )
    }

    override func setup() {
        floor.position.y = -0.95

        metallicSphere.position = [-1.35, 0.0, 0.0]
        matteSphere.position = [0.0, 0.0, -0.10]
        brushedSphere.position = [1.30, 0.10, -0.30]

        directional.position = [3.0, 5.0, 4.0]
        directional.lookAt(target: .zero)

        fill.position = [-2.0, 1.5, 2.5]

        camera.lookAt(target: .zero)
    }

    override func update() {
        cameraController.update()
        let time = Float(getTime() - startTime)
        metallicSphere.orientation = simd_quatf(angle: time * 0.6, axis: normalize([0.35, 1.0, 0.2]))
        brushedSphere.orientation = simd_quatf(angle: -time * 0.4, axis: normalize([0.2, 1.0, 0.3]))
    }

    override func draw(renderPassDescriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer) {
        renderer.draw(
            renderPassDescriptor: renderPassDescriptor,
            commandBuffer: commandBuffer,
            scene: scene,
            camera: camera
        )
    }

    override func draw(renderPassDescriptor: MTLRenderPassDescriptor, frameCommand: any SatinFrameCommand) -> Bool {
        renderer.draw(
            renderPassDescriptor: renderPassDescriptor,
            frameCommand: frameCommand,
            scene: scene,
            camera: camera
        )
    }

    override func resize(size: (width: Float, height: Float), scaleFactor _: Float) {
        camera.aspect = size.width / size.height
        renderer.resize(size)
    }
}

private extension Context {
    /// Returns a copy of this context with `renderingMode` overridden. Used by the
    /// Metal 4 deferred example to avoid duplicating the platform-default setup.
    func with(renderingMode: RenderingMode) -> Context {
        Context(
            device: device,
            backend: requestedBackend,
            sampleCount: sampleCount,
            colorPixelFormat: colorPixelFormat,
            depthPixelFormat: depthPixelFormat,
            stencilPixelFormat: stencilPixelFormat,
            vertexAmplificationCount: vertexAmplificationCount,
            maxBuffersInFlight: maxBuffersInFlight,
            renderingMode: renderingMode,
            activeOutputs: [.color, .albedo, .normals, .pbr, .velocity, .emissive],
            alphaOitEnabled: alphaOitEnabled,
            albedoPixelFormat: albedoPixelFormat,
            normalsPixelFormat: normalsPixelFormat,
            pbrPixelFormat: pbrPixelFormat,
            velocityPixelFormat: velocityPixelFormat,
            emissivePixelFormat: emissivePixelFormat
        )
    }
}
