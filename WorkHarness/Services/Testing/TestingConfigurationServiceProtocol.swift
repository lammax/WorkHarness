//
// TestingConfigurationServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 24.07.2026.
//

import Foundation

@MainActor
protocol TestingConfigurationServiceProtocol: BaseServiceProtocol {
    var catalog: TestingConfigurationCatalog { get }
    var configurationDirectoryPath: String? { get }

    func reload()
    func saveTarget(_ target: TestingTargetConfiguration) throws
    func scenarioPrompt(for scenarioId: UUID) -> String
    func scenarioFileURL(for scenarioId: UUID) throws -> URL
    func setScenarioEnabled(id: UUID, enabled: Bool) throws
    func moveScenario(id: UUID, direction: SmokeScenarioMoveDirection) throws
    func replaceScenario(for scenarioId: UUID, withContentsOf sourceURL: URL) throws
}

extension TestingConfigurationServiceProtocol {
    var service: AppService { .testing }
}

enum SmokeScenarioMoveDirection {
    case up
    case down
}

enum TestingConfigurationServiceError: LocalizedError, Equatable {
    case projectRootUnavailable
    case scenarioNotFound
    case scenarioFileUnavailable
    case invalidMarkdownFile

    var errorDescription: String? {
        switch self {
        case .projectRootUnavailable:
            "Select a project with a root folder before configuring tests."
        case .scenarioNotFound:
            "The selected smoke scenario no longer exists."
        case .scenarioFileUnavailable:
            "The smoke scenario file is unavailable."
        case .invalidMarkdownFile:
            "The smoke scenario must be a non-empty Markdown file."
        }
    }
}
