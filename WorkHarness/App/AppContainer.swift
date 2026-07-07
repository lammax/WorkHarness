//
// AppContainer.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation
import Swinject

@MainActor
final class AppContainer {
    private lazy var container: Container = {
        let container = Container().synchronize() as! Container
        container.registerDependencies()
        return container
    }()

    private static let shared = AppContainer()

    private init() {}

    static var resolver: Container {
        AppContainer.shared.container
    }
}
