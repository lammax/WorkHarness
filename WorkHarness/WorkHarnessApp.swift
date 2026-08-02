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

    init() {
        let runService = AppContainer.resolver.resolve(RunServiceProtocol.self)!
        runService.reconcileInterruptedRuns()
        let remoteControl = AppContainer.resolver.resolve(RemoteControlServiceProtocol.self)!
        remoteControl.start()
    }

    var body: some Scene {
        WindowGroup {
            scene.content
        }
    }
}
