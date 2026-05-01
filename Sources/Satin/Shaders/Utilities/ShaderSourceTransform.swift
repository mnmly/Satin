//
//  ShaderSourceTransform.swift
//  Satin
//
//  Created by Hiroaki Yamane on 2026-05-01.
//

import Foundation

public protocol ShaderSourceTransform: Sendable {
    func transform(source: inout String, configuration: ShaderLibraryConfiguration)
}
