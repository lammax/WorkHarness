//
//  WorkHarnessApp.swift
//  WorkHarness
//
//  Created by Максим Ламанский on 7.07.26.
//

import SwiftUI
import Swinject

@main
struct WorkHarnessApp: App {
    private let scene = AppContainer.resolver.resolve(AppSceneProtocol.self)!

    var body: some Scene {
        WindowGroup {
            scene.content
        }
    }
}
