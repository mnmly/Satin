//
//  Mesh+LOD.swift
//  Satin
//
//  Created by Hiroaki Yamane on 7/2/25.
//

import Foundation
import Metal
import simd

#if SWIFT_PACKAGE
import SatinCore
#endif

public extension Mesh {
    struct LODLevel {
        public let geometry: Geometry?
        public let screenSpaceRadius: Float
        
        public init(geometry: Geometry?, screenSpaceRadius: Float) {
            self.geometry = geometry
            self.screenSpaceRadius = screenSpaceRadius
        }
    }
    
    private struct AssociatedKeys {
        static var lodLevels: UInt8 = 0
        static var lodEnabled: UInt8 = 0
        static var manualLODIndex: UInt8 = 0
        static var currentLODIndex: UInt8 = 0
    }
    
    var lodLevels: [LODLevel] {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.lodLevels) as? [LODLevel] ?? []
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.lodLevels, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var lodEnabled: Bool {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.lodEnabled) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.lodEnabled, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var manualLODIndex: Int? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.manualLODIndex) as? Int
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.manualLODIndex, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private var currentLODIndex: Int {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.currentLODIndex) as? Int ?? 0
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.currentLODIndex, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func addLODLevel(geometry: Geometry?, screenSpaceRadius: Float) {
        let lodLevel = LODLevel(geometry: geometry, screenSpaceRadius: screenSpaceRadius)
        lodLevels.append(lodLevel)
        lodLevels.sort { $0.screenSpaceRadius > $1.screenSpaceRadius }
    }
    
    func removeLODLevel(at index: Int) {
        guard index >= 0 && index < lodLevels.count else { return }
        lodLevels.remove(at: index)
    }
    
    func clearLODLevels() {
        lodLevels.removeAll()
    }
    
    func updateLOD(camera: Camera, viewport: simd_float4) {
        guard lodEnabled && !lodLevels.isEmpty else { return }
        guard let camera = camera as? PerspectiveCamera else { return }
        
        if let manualIndex = manualLODIndex {
            let selectedIndex = min(max(manualIndex, 0), lodLevels.count - 1)
            if selectedIndex != currentLODIndex {
                currentLODIndex = selectedIndex
                if let selectedGeometry = lodLevels[currentLODIndex].geometry {
                    geometry = selectedGeometry
                }
            }
            return
        }
        
        let screenSpaceRadius = calculateScreenSpaceRadius(camera: camera, viewport: viewport)
        
        var selectedIndex = lodLevels.count - 1
        for (index, lodLevel) in lodLevels.enumerated() {
            if screenSpaceRadius >= lodLevel.screenSpaceRadius {
                selectedIndex = index
                break
            }
        }
        
        if selectedIndex != currentLODIndex {
            currentLODIndex = selectedIndex
            if let selectedGeometry = lodLevels[currentLODIndex].geometry {
                geometry = selectedGeometry
            }
        }
    }
    
    private func calculateScreenSpaceRadius(camera: PerspectiveCamera, viewport: simd_float4) -> Float {
        let bounds = worldBounds
        let center = (bounds.min + bounds.max) * 0.5
        let radius = simd_length(bounds.max - bounds.min) * 0.5
        
        let cameraDistance = simd_length(camera.worldPosition - center)
        
        guard cameraDistance > 0 else { return Float.greatestFiniteMagnitude }
        
        let viewportHeight = viewport.w
        let fov = camera.fov
        let halfFovTan = tan(fov * 0.5)
        
        let projectedRadius = (radius / cameraDistance) * (viewportHeight * 0.5) / halfFovTan
        
        return projectedRadius
    }
    
    var currentScreenSpaceRadius: Float? {
        guard lodEnabled && currentLODIndex < lodLevels.count else { return nil }
        return lodLevels[currentLODIndex].screenSpaceRadius
    }
    
    var currentLODLevel: Int? {
        guard lodEnabled else { return nil }
        return currentLODIndex
    }
}
