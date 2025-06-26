import Foundation
import simd

#if SWIFT_PACKAGE
import SatinCore
#endif

// Extension to Material for easy registration
extension Material {
    public func registerCustomShaderInjector(_ injector: CustomShaderInjector) {
        ShaderLibrarySourceCache.registerCustomInjector(injector, for: self.label)
    }
    
    public func unregisterCustomShaderInjector() {
        ShaderLibrarySourceCache.unregisterCustomInjector(for: self.label)
    }
}
