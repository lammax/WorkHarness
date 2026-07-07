//
// SceneRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Swinject

extension Container {
    func registerScene() {
        register(AppSceneProtocol.self) { resolver in
            AppScene(rootScreen: resolver.resolve(MainScreenProtocol.self)!)
        }.inObjectScope(.container)
    }
}
