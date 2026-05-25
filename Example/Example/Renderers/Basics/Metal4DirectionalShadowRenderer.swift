//
//  Metal4DirectionalShadowRenderer.swift
//  Example
//
//  Same forward + directional shadow scene as DirectionalShadowRenderer, on the
//  Metal 4 frame-command backend. Demonstrates shadow caster + receiver paths
//  routing through MTL4 argument tables and residency sets.
//

import Metal
import MetalKit
import Satin

final class Metal4DirectionalShadowRenderer: BaseRenderer {
    override var texturesURL: URL { sharedAssetsURL.appendingPathComponent("Textures") }

    lazy var baseMesh = Mesh(
        context: defaultContext,
        geometry: BoxGeometry(context: defaultContext, width: 1.25, height: 0.125, depth: 1.25, resolution: 5),
        material: StandardMaterial(context: defaultContext, baseColor: [1.0, 1.0, 1.0, 1.0], metallic: 0.75, roughness: 0.25)
    )

    lazy var torusMesh = Mesh(
        context: defaultContext,
        geometry: TorusGeometry(context: defaultContext, minorRadius: 0.1, majorRadius: 0.5),
        material: StandardMaterial(context: defaultContext, baseColor: [1, 1, 1, 1], metallic: 1.0, roughness: 0.25, specular: 1.0)
    )

    lazy var sphereMesh = Mesh(
        context: defaultContext,
        geometry: IcoSphereGeometry(context: defaultContext, radius: 0.25, resolution: 3),
        material: StandardMaterial(context: defaultContext, baseColor: .one, metallic: 0.8, roughness: 0.5, specular: 1.0)
    )

    lazy var floorMesh = Mesh(
        context: defaultContext,
        geometry: PlaneGeometry(context: defaultContext, size: 8.0, orientation: .zx),
        material: StandardMaterial(context: defaultContext, baseColor: [0.72, 0.74, 0.78, 1.0], metallic: 0.0, roughness: 0.95)
    )

    lazy var light = DirectionalLight(context: defaultContext, color: [1.0, 1.0, 1.0], intensity: 1.0)
    lazy var scene = IBLScene(context: defaultContext, label: "Scene", [light, floorMesh, baseMesh, sphereMesh, torusMesh])
    lazy var camera = PerspectiveCamera(context: defaultContext, position: .init(repeating: 5.0), near: 0.01, far: 500.0, fov: 30)
    lazy var cameraController = PerspectiveCameraController(camera: camera, view: metalView)
    lazy var renderer = RenderEncoder(context: defaultContext)

    init() {
        super.init(context: .makePlatformDefault(backend: .metal4))
    }

    func loadHdri() {
        let filename = "brown_photostudio_02_2k.hdr"
        if let hdr = loadHDR(device: device, url: texturesURL.appendingPathComponent(filename)) {
            scene.setEnvironment(texture: hdr)
            scene.environmentIntensity = 0.5
        }
    }

    override func setup() {
        loadHdri()
        renderer.clearColor = .init(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0)

        light.position.y = 5.0
        light.castShadow = true
        if let shadowCamera = light.shadow.camera as? OrthographicCamera {
            shadowCamera.update(left: -2, right: 2, bottom: -2, top: 2)
        }
        light.shadow.resolution = (2048, 2048)
        light.shadow.bias = 0.0005
        light.shadow.strength = 1
        light.shadow.radius = 2

        camera.lookAt(target: .zero)
        floorMesh.position.y = -1.0

        torusMesh.label = "Torus"
        torusMesh.castShadow = true
        torusMesh.receiveShadow = true

        sphereMesh.label = "Sphere"
        sphereMesh.castShadow = true
        sphereMesh.receiveShadow = true

        baseMesh.label = "Base"
        baseMesh.position.y = -0.75
        baseMesh.castShadow = true
        baseMesh.receiveShadow = true

        floorMesh.label = "Floor"
        floorMesh.receiveShadow = true
    }

    lazy var startTime = getTime()

    override func update() {
        cameraController.update()
        let time = Float(getTime() - startTime)
        let radius: Float = 5.0
        torusMesh.orientation = simd_quatf(angle: time, axis: Satin.worldUpDirection)
            * simd_quatf(angle: time, axis: Satin.worldRightDirection)
        light.position = simd_make_float3(radius * sin(time), 5.0, radius * cos(time))
        light.lookAt(target: .zero, up: Satin.worldUpDirection)
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
