//
//  Metal4DeferredRendererView.swift
//  Example
//

import Satin
import SwiftUI

struct Metal4DeferredRendererView: View {
    var body: some View {
        SatinMetalView(renderer: Metal4DeferredRenderer())
            .ignoresSafeArea()
            .navigationTitle("Metal 4 Deferred")
    }
}

struct Metal4DeferredRendererView_Previews: PreviewProvider {
    static var previews: some View {
        Metal4DeferredRendererView()
    }
}
