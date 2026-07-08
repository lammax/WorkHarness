//
// AppSettingsServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

@MainActor
protocol AppSettingsServiceProtocol: BaseServiceProtocol {
    var defaultProviderId: String? { get set }
}

extension AppSettingsServiceProtocol {
    var service: AppService { .appSettings }
}
