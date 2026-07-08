//
// UserDefaultsAppSettingsService.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Foundation

@MainActor
final class UserDefaultsAppSettingsService: AppSettingsServiceProtocol {
    private enum Key {
        static let defaultProviderId = "appSettings.defaultProviderId"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var defaultProviderId: String? {
        get {
            defaults.string(forKey: Key.defaultProviderId)
        }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.defaultProviderId)
            } else {
                defaults.removeObject(forKey: Key.defaultProviderId)
            }
        }
    }
}
