import Metal
@testable import Satin
import XCTest

final class RenderEncoderStateBackendTests: XCTestCase {
    func testClassicRenderEncoderStateExposesClassicEncoder() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let commandQueue = try XCTUnwrap(device.makeCommandQueue())
        let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
        let renderPassDescriptor = try makeRenderPassDescriptor(device: device)
        let renderEncoder = try XCTUnwrap(commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor))

        let state = RenderEncoderState(renderEncoder: renderEncoder)

        XCTAssertTrue(state.supportsClassicRenderEncoder)
        XCTAssertTrue(state.supportsTessellation)
        XCTAssertTrue(state.renderEncoder === renderEncoder)

        let samplerDescriptor = MTLSamplerDescriptor()
        let samplerState = try XCTUnwrap(device.makeSamplerState(descriptor: samplerDescriptor))
        state.setFragmentSamplerState(samplerState, index: .Custom0)

        let texture = try XCTUnwrap(makeTexture(device: device))
        state.setFragmentTextures([texture], startIndex: .Projector0)
        state.useFragmentResource(texture)

        let tessellationFactorBuffer = try XCTUnwrap(device.makeBuffer(length: 256))
        XCTAssertTrue(state.setTessellationFactorBuffer(tessellationFactorBuffer, offset: 0, instanceStride: 0))

        renderEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    func testMetal4RenderEncoderStateDoesNotExposeClassicEncoder() throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("Metal 4 render encoder state requires OS 26 SDK runtime support.")
        }

        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let support = try XCTUnwrap(Metal4Support(device: device, maxBuffersInFlight: 1))
        let frameCommand = try XCTUnwrap(support.makeFrameCommand(frameIndex: 0))
        let renderPassDescriptor = try makeRenderPassDescriptor(device: device)
        let renderCommand = try XCTUnwrap(support.makeRenderCommand(renderPassDescriptor: renderPassDescriptor))
        let argumentTables = try XCTUnwrap(Metal4ArgumentTables(device: device))

        let state = RenderEncoderState(
            metal4RenderEncoder: renderCommand.renderEncoder,
            argumentTables: argumentTables
        )

        XCTAssertFalse(state.supportsClassicRenderEncoder)
        XCTAssertFalse(state.supportsTessellation)

        let texture = try XCTUnwrap(makeTexture(device: device))
        state.setFragmentTextures([texture], startIndex: .Projector0)
        state.useFragmentResource(texture)

        let tessellationFactorBuffer = try XCTUnwrap(device.makeBuffer(length: 256))
        XCTAssertFalse(state.setTessellationFactorBuffer(tessellationFactorBuffer, offset: 0, instanceStride: 0))

        renderCommand.renderEncoder.endEncoding()
        frameCommand.end()
    }

    private func makeRenderPassDescriptor(device: MTLDevice) throws -> MTLRenderPassDescriptor {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget]

        let texture = try XCTUnwrap(device.makeTexture(descriptor: textureDescriptor))
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        return renderPassDescriptor
    }

    private func makeTexture(device: MTLDevice) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead]
        return device.makeTexture(descriptor: textureDescriptor)
    }
}
