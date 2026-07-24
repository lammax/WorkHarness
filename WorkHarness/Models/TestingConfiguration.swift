//
// TestingConfiguration.swift
// WorkHarness
//
// Created by Auto (Codex) on 24.07.2026.
//

import Foundation

enum SmokeTestPlatform: String, Codable, CaseIterable, Equatable {
    case iOSSimulator
    case macOSDesktop
    case browser

    var title: String {
        switch self {
        case .iOSSimulator: "iOS Simulator"
        case .macOSDesktop: "macOS Desktop"
        case .browser: "Browser"
        }
    }
}

struct TestingTargetConfiguration: Codable, Equatable {
    var platform: SmokeTestPlatform
    var xcodeContainerPath: String
    var scheme: String
    var bundleIdentifier: String
    var deviceName: String
    var buildCommand: String
    var codeTestCommand: String
}

struct SmokeScenario: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var summary: String
    var promptFileName: String
    var enabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        summary: String,
        promptFileName: String,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.promptFileName = promptFileName
        self.enabled = enabled
    }
}

struct TestingConfigurationCatalog: Codable, Equatable {
    var target: TestingTargetConfiguration
    var scenarios: [SmokeScenario]
}
