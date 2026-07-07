//
//  ContentView.swift
//  WorkHarness
//
//  Created by Максим Ламанский on 7.07.26.
//

import SwiftUI
import Swinject

struct ContentView: View {
    let scene: any AppSceneProtocol

    var body: some View {
        scene.content
    }
}

#Preview {
    ContentView(scene: AppContainer.resolver.resolve(AppSceneProtocol.self)!)
}
