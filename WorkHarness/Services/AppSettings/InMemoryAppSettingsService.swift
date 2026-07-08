//
// InMemoryAppSettingsService.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

@MainActor
final class InMemoryAppSettingsService: AppSettingsServiceProtocol {
    var defaultProviderId: String?

    init(defaultProviderId: String? = nil) {
        self.defaultProviderId = defaultProviderId
    }
}
