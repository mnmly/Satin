//
//  Metal4DirectionalShadowRendererView.swift
//  Example
//

import Satin
import SwiftUI

struct Metal4DirectionalShadowRendererView: View {
    var body: some View {
        SatinMetalView(renderer: Metal4DirectionalShadowRenderer())
            .ignoresSafeArea()
            .navigationTitle("Metal 4 Directional Shadow")
    }
}

struct Metal4DirectionalShadowRendererView_Previews: PreviewProvider {
    static var previews: some View {
        Metal4DirectionalShadowRendererView()
    }
}
