//
// TestingConfigurationService.swift
// WorkHarness
//
// Created by Auto (Codex) on 24.07.2026.
//

import Foundation

@MainActor
final class TestingConfigurationService: TestingConfigurationServiceProtocol {
    private let projectService: ProjectServiceProtocol
    private let fileManager: FileManager
    private var loadedRootPath: String?
    private var loadedPrompts: [UUID: String] = [:]

    private(set) var catalog = TestingConfigurationDefaults.catalog

    init(
        projectService: ProjectServiceProtocol,
        fileManager: FileManager = .default
    ) {
        self.projectService = projectService
        self.fileManager = fileManager
        reload()
    }

    var configurationDirectoryPath: String? {
        configurationDirectoryURL?.path
    }

    func reload() {
        guard let directoryURL = configurationDirectoryURL else {
            loadedRootPath = nil
            applyBuiltInCatalog()
            return
        }

        do {
            try seedCatalogIfNeeded(at: directoryURL)
            let manifestURL = directoryURL.appendingPathComponent(
                TestingConfigurationDefaults.manifestFileName
            )
            let data = try Data(contentsOf: manifestURL)
            catalog = try JSONDecoder().decode(TestingConfigurationCatalog.self, from: data)
            loadedRootPath = projectService.currentProject?.rootPath
            loadPrompts(from: directoryURL)
        } catch {
            applyBuiltInCatalog()
        }
    }

    func saveTarget(_ target: TestingTargetConfiguration) throws {
        ensureCurrentProjectIsLoaded()
        catalog.target = target
        try persistCatalog()
    }

    func scenarioPrompt(for scenarioId: UUID) -> String {
        ensureCurrentProjectIsLoaded()
        return loadedPrompts[scenarioId] ?? ""
    }

    func scenarioFileURL(for scenarioId: UUID) throws -> URL {
        ensureCurrentProjectIsLoaded()
        guard let scenarioDirectoryURL else {
            throw TestingConfigurationServiceError.projectRootUnavailable
        }
        guard let scenario = catalog.scenarios.first(where: { $0.id == scenarioId }) else {
            throw TestingConfigurationServiceError.scenarioNotFound
        }
        let fileURL = scenarioDirectoryURL.appendingPathComponent(scenario.promptFileName)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw TestingConfigurationServiceError.scenarioFileUnavailable
        }
        return fileURL
    }

    func setScenarioEnabled(id: UUID, enabled: Bool) throws {
        ensureCurrentProjectIsLoaded()
        guard let index = catalog.scenarios.firstIndex(where: { $0.id == id }) else {
            throw TestingConfigurationServiceError.scenarioNotFound
        }
        catalog.scenarios[index].enabled = enabled
        try persistCatalog()
    }

    func moveScenario(id: UUID, direction: SmokeScenarioMoveDirection) throws {
        ensureCurrentProjectIsLoaded()
        guard let index = catalog.scenarios.firstIndex(where: { $0.id == id }) else {
            throw TestingConfigurationServiceError.scenarioNotFound
        }
        let destinationIndex = direction == .up ? index - 1 : index + 1
        guard catalog.scenarios.indices.contains(destinationIndex) else { return }
        catalog.scenarios.swapAt(index, destinationIndex)
        try persistCatalog()
    }

    func replaceScenario(for scenarioId: UUID, withContentsOf sourceURL: URL) throws {
        ensureCurrentProjectIsLoaded()
        guard let scenarioDirectoryURL else {
            throw TestingConfigurationServiceError.projectRootUnavailable
        }
        guard let scenario = catalog.scenarios.first(where: { $0.id == scenarioId }) else {
            throw TestingConfigurationServiceError.scenarioNotFound
        }
        guard sourceURL.pathExtension.lowercased() == "md",
              let contents = try? String(contentsOf: sourceURL, encoding: .utf8),
              !contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TestingConfigurationServiceError.invalidMarkdownFile
        }

        try fileManager.createDirectory(at: scenarioDirectoryURL, withIntermediateDirectories: true)
        try contents.write(
            to: scenarioDirectoryURL.appendingPathComponent(scenario.promptFileName),
            atomically: true,
            encoding: .utf8
        )
        loadedPrompts[scenario.id] = contents
    }

    private var configurationDirectoryURL: URL? {
        guard let rootPath = projectService.currentProject?.rootPath,
              !rootPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: rootPath, isDirectory: true)
            .appendingPathComponent(TestingConfigurationDefaults.directoryName, isDirectory: true)
    }

    private var scenarioDirectoryURL: URL? {
        configurationDirectoryURL?.appendingPathComponent(
            TestingConfigurationDefaults.scenarioDirectoryName,
            isDirectory: true
        )
    }

    private func ensureCurrentProjectIsLoaded() {
        if loadedRootPath != projectService.currentProject?.rootPath {
            reload()
        }
    }

    private func seedCatalogIfNeeded(at directoryURL: URL) throws {
        let scenarioDirectoryURL = directoryURL.appendingPathComponent(
            TestingConfigurationDefaults.scenarioDirectoryName,
            isDirectory: true
        )
        let reportsDirectoryURL = directoryURL.appendingPathComponent(
            TestingConfigurationDefaults.reportsDirectoryName,
            isDirectory: true
        )
        try fileManager.createDirectory(at: scenarioDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: reportsDirectoryURL, withIntermediateDirectories: true)

        let manifestURL = directoryURL.appendingPathComponent(
            TestingConfigurationDefaults.manifestFileName
        )
        if !fileManager.fileExists(atPath: manifestURL.path) {
            try encodedCatalog(TestingConfigurationDefaults.catalog).write(
                to: manifestURL,
                options: .atomic
            )
        }

        for (fileName, prompt) in TestingConfigurationDefaults.scenarioPrompts {
            let fileURL = scenarioDirectoryURL.appendingPathComponent(fileName)
            if !fileManager.fileExists(atPath: fileURL.path) {
                try prompt.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
    }

    private func loadPrompts(from directoryURL: URL) {
        let scenarioDirectoryURL = directoryURL.appendingPathComponent(
            TestingConfigurationDefaults.scenarioDirectoryName,
            isDirectory: true
        )
        loadedPrompts = [:]
        for scenario in catalog.scenarios {
            let fileURL = scenarioDirectoryURL.appendingPathComponent(scenario.promptFileName)
            if let prompt = try? String(contentsOf: fileURL, encoding: .utf8) {
                loadedPrompts[scenario.id] = prompt
            }
        }
    }

    private func persistCatalog() throws {
        guard let directoryURL = configurationDirectoryURL else {
            throw TestingConfigurationServiceError.projectRootUnavailable
        }
        try encodedCatalog(catalog).write(
            to: directoryURL.appendingPathComponent(TestingConfigurationDefaults.manifestFileName),
            options: .atomic
        )
    }

    private func encodedCatalog(_ catalog: TestingConfigurationCatalog) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(catalog)
    }

    private func applyBuiltInCatalog() {
        catalog = TestingConfigurationDefaults.catalog
        loadedPrompts = Dictionary(
            uniqueKeysWithValues: catalog.scenarios.compactMap { scenario in
                TestingConfigurationDefaults.scenarioPrompts[scenario.promptFileName].map {
                    (scenario.id, $0)
                }
            }
        )
    }
}
