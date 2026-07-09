//
// ScreensRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Swinject

extension Container {
    func registerScreens() {
        register(MainScreen.ChatPageViewModel.self) { resolver in
            MainScreen.ChatPageViewModel(runService: resolver.resolve(RunServiceProtocol.self)!)
        }.inObjectScope(.container)

        register(MainScreen.RunsPageViewModel.self) { resolver in
            MainScreen.RunsPageViewModel(runService: resolver.resolve(RunServiceProtocol.self)!)
        }.inObjectScope(.container)

        register(MainScreen.StatsPageViewModel.self) { resolver in
            MainScreen.StatsPageViewModel(statisticsService: resolver.resolve(UsageStatisticsServiceProtocol.self)!)
        }.inObjectScope(.container)

        register(MainScreen.SettingsPageViewModel.self) { resolver in
            MainScreen.SettingsPageViewModel(
                providerService: resolver.resolve(ProviderServiceProtocol.self)!,
                appSettingsService: resolver.resolve(AppSettingsServiceProtocol.self)!
            )
        }.inObjectScope(.container)

        register(MainScreenProtocol.self) { resolver in
            MainScreen(
                chatPageViewModel: resolver.resolve(MainScreen.ChatPageViewModel.self)!,
                runsPageViewModel: resolver.resolve(MainScreen.RunsPageViewModel.self)!,
                statsPageViewModel: resolver.resolve(MainScreen.StatsPageViewModel.self)!,
                settingsPageViewModel: resolver.resolve(MainScreen.SettingsPageViewModel.self)!,
                approvalService: resolver.resolve(ApprovalServiceProtocol.self)!,
                projectService: resolver.resolve(ProjectServiceProtocol.self)!
            )
        }.inObjectScope(.transient)
    }
}
