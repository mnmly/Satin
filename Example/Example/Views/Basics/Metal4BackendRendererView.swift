//
//  Metal4BackendRendererView.swift
//  Example
//

import Satin
import SwiftUI

struct Metal4BackendRendererView: View {
    var body: some View {
        SatinMetalView(renderer: Metal4BackendRenderer())
            .ignoresSafeArea()
            .navigationTitle("Metal 4 Backend")
    }
}

struct Metal4BackendRendererView_Previews: PreviewProvider {
    static var previews: some View {
        Metal4BackendRendererView()
    }
}
