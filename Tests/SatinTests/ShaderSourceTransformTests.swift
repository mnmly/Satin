//
//  ShaderSourceTransformTests.swift
//  SatinTests
//
//  Created by Hiroaki Yamane on 2026-05-01.
//

import Metal
import Satin
import XCTest

private struct AppendMarkerTransform: ShaderSourceTransform {
    let marker: String
    func transform(source: inout String, configuration: ShaderLibraryConfiguration) {
        source += "\n// \(marker)\n"
    }
}

private struct AppendComputeMarkerTransform: ComputeShaderSourceTransform {
    let marker: String
    func transform(source: inout String, configuration: ComputeShaderLibraryConfiguration) {
        source += "\n// \(marker)\n"
    }
}

final class ShaderSourceTransformTests: XCTestCase {
    private func makeContext() -> Context? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        return Context(device: device, sampleCount: 1, colorPixelFormat: .bgra8Unorm)
    }

    private func makeBasicColorShader(_ context: Context) -> SourceShader {
        let pipelineURL = getPipelinesMaterialsURL("BasicColor")!.appendingPathComponent("Shaders.metal")
        return SourceShader(context: context, label: "BasicColor", pipelineURL: pipelineURL)
    }

    // MARK: - Render

    func testTransformIsApplied() throws {
        guard let context = makeContext() else { throw XCTSkip("Metal unavailable") }
        let shader = makeBasicColorShader(context)

        let baseline = shader.source
        XCTAssertNotNil(baseline)
        XCTAssertFalse(baseline!.contains("MARKER_A"))

        shader.sourceTransforms = [AppendMarkerTransform(marker: "MARKER_A")]
        let transformed = shader.source
        XCTAssertNotNil(transformed)
        XCTAssertTrue(transformed!.contains("// MARKER_A"))
    }

    func testTransformsRunInOrder() throws {
        guard let context = makeContext() else { throw XCTSkip("Metal unavailable") }
        let shader = makeBasicColorShader(context)

        shader.sourceTransforms = [
            AppendMarkerTransform(marker: "FIRST"),
            AppendMarkerTransform(marker: "SECOND"),
        ]

        let source = try XCTUnwrap(shader.source)
        let firstRange = try XCTUnwrap(source.range(of: "// FIRST"))
        let secondRange = try XCTUnwrap(source.range(of: "// SECOND"))
        XCTAssertLessThan(firstRange.lowerBound, secondRange.lowerBound)
    }

    func testReplacingTransformsInvalidatesCache() throws {
        guard let context = makeContext() else { throw XCTSkip("Metal unavailable") }
        let shader = makeBasicColorShader(context)

        shader.sourceTransforms = [AppendMarkerTransform(marker: "OLD")]
        let first = try XCTUnwrap(shader.source)
        XCTAssertTrue(first.contains("// OLD"))

        shader.sourceTransforms = [AppendMarkerTransform(marker: "NEW")]
        let second = try XCTUnwrap(shader.source)
        XCTAssertTrue(second.contains("// NEW"))
        XCTAssertFalse(second.contains("// OLD"))
    }

    func testEmptyingTransformsRestoresBaseline() throws {
        guard let context = makeContext() else { throw XCTSkip("Metal unavailable") }
        let shader = makeBasicColorShader(context)

        let baseline = try XCTUnwrap(shader.source)

        shader.sourceTransforms = [AppendMarkerTransform(marker: "TEMP")]
        XCTAssertTrue(try XCTUnwrap(shader.source).contains("// TEMP"))

        shader.sourceTransforms = []
        let restored = try XCTUnwrap(shader.source)
        XCTAssertFalse(restored.contains("// TEMP"))
        XCTAssertEqual(restored, baseline)
    }

    // MARK: - Material pass-through

    func testMaterialForwardsTransformsToShader() throws {
        guard let context = makeContext() else { throw XCTSkip("Metal unavailable") }

        let pipelineURL = getPipelinesMaterialsURL("BasicColor")!.appendingPathComponent("Shaders.metal")
        let material = SourceMaterial(context: context, pipelineURL: pipelineURL)
        material.label = "BasicColor"
        material.update()

        material.sourceTransforms = [AppendMarkerTransform(marker: "VIA_MATERIAL")]

        let shader = try XCTUnwrap(material.shader as? SourceShader)
        XCTAssertEqual(shader.sourceTransforms.count, 1, "material setter forwards to shader")
        XCTAssertTrue(try XCTUnwrap(shader.source).contains("// VIA_MATERIAL"))
    }

    // MARK: - Compute

    private func makeComputeShader() -> ComputeShader? {
        guard let url = getPipelinesComputeURL("RandomNoise")?.appendingPathComponent("Shaders.metal"),
              FileManager.default.fileExists(atPath: url.path)
        else { return nil }
        return ComputeShader(label: "RandomNoise", pipelineURL: url)
    }

    func testComputeTransformIsApplied() throws {
        guard let shader = makeComputeShader() else { throw XCTSkip("RandomNoise pipeline not available") }

        let baseline = shader.source
        XCTAssertNotNil(baseline)
        XCTAssertFalse(baseline!.contains("COMPUTE_MARKER"))

        shader.sourceTransforms = [AppendComputeMarkerTransform(marker: "COMPUTE_MARKER")]
        let transformed = try XCTUnwrap(shader.source)
        XCTAssertTrue(transformed.contains("// COMPUTE_MARKER"))
    }

    func testComputeTransformsInvalidateCache() throws {
        guard let shader = makeComputeShader() else { throw XCTSkip("RandomNoise pipeline not available") }

        shader.sourceTransforms = [AppendComputeMarkerTransform(marker: "OLD")]
        XCTAssertTrue(try XCTUnwrap(shader.source).contains("// OLD"))

        shader.sourceTransforms = [AppendComputeMarkerTransform(marker: "NEW")]
        let second = try XCTUnwrap(shader.source)
        XCTAssertTrue(second.contains("// NEW"))
        XCTAssertFalse(second.contains("// OLD"))
    }
}
