//
// DependencyRegistration.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Swinject

extension Container {
    func registerDependencies() {
        registerRepositories()
        registerProcessRunner()
        registerProviders()
        registerEngine()
        registerServices()
        registerScreens()
        registerScene()
    }
}
