//
//  Metal4BackendRenderer.swift
//  Example
//

import Metal
import MetalKit
import Satin

final class Metal4BackendRenderer: BaseRenderer {
    lazy var material = BasicDiffuseMaterial(
        context: defaultContext,
        color: context.backend == .metal4 ? [0.2, 0.8, 1.0, 1.0] : [1.0, 0.55, 0.2, 1.0],
        hardness: 0.7
    )

    lazy var mesh = Mesh(
        context: defaultContext,
        label: "Metal 4 Sphere",
        geometry: IcoSphereGeometry(context: defaultContext, radius: 0.7, resolution: 3),
        material: material
    )

    lazy var floor = Mesh(
        context: defaultContext,
        label: "Floor",
        geometry: PlaneGeometry(context: defaultContext, size: 3.0),
        material: BasicDiffuseMaterial(context: defaultContext, color: [0.35, 0.35, 0.38, 1.0], hardness: 0.45)
    )

    lazy var light = DirectionalLight(context: defaultContext, color: .one)
    lazy var scene = Object(context: defaultContext, label: "Scene", [mesh, floor, light])
    lazy var renderer = RenderEncoder(context: defaultContext)
    lazy var camera = PerspectiveCamera(context: defaultContext, position: [0, 1.0, 4.0], near: 0.1, far: 100.0, fov: 35)
    lazy var cameraController = PerspectiveCameraController(camera: camera, view: metalView)
    lazy var startTime = getTime()

    init() {
        super.init(context: .makePlatformDefault(backend: .metal4))
    }

    override func setup() {
        floor.orientation = simd_quatf(angle: -.pi * 0.5, axis: [1, 0, 0])
        floor.position.y = -0.85

        light.position = [3, 5, 4]
        light.lookAt(target: .zero)
        camera.lookAt(target: .zero)

        #if os(visionOS)
        renderer.setClearColor(.zero)
        metalView.backgroundColor = .clear
        #endif
    }

    override func update() {
        cameraController.update()
        mesh.orientation = simd_quatf(angle: Float(getTime() - startTime), axis: normalize([0.35, 1.0, 0.2]))
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
