//
// AgentProfileService.swift
// WorkHarness
//
// Created by Auto (Codex) on 24.07.2026.
//

import Foundation

@MainActor
final class AgentProfileService: AgentProfileServiceProtocol {
    private let projectService: ProjectServiceProtocol
    private let fileManager: FileManager
    private var loadedRootPath: String?
    private var loadedPrompts: [UUID: String] = [:]

    private(set) var profiles: [AgentWorkflowProfile] = AgentProfileDefaults.catalog.profiles
    private(set) var selectedProfileId: String = AgentProfileDefaults.selectedProfileId

    init(
        projectService: ProjectServiceProtocol,
        fileManager: FileManager = .default
    ) {
        self.projectService = projectService
        self.fileManager = fileManager
        reload()
    }

    var selectedProfile: AgentWorkflowProfile? {
        ensureCurrentProjectIsLoaded()
        return profiles.first { $0.id == selectedProfileId }
    }

    var promptDirectoryPath: String? {
        promptDirectoryURL?.path
    }

    func reload() {
        guard let directoryURL = promptDirectoryURL else {
            loadedRootPath = nil
            applyBuiltInCatalog()
            return
        }

        do {
            try seedCatalogIfNeeded(at: directoryURL)
            let manifestURL = directoryURL.appendingPathComponent(AgentProfileDefaults.manifestFileName)
            let data = try Data(contentsOf: manifestURL)
            let storedCatalog = try JSONDecoder().decode(AgentProfileCatalog.self, from: data)
            let catalog = catalogByAddingMissingBuiltInContent(to: storedCatalog)
            if catalog != storedCatalog {
                try encodedCatalog(catalog).write(to: manifestURL, options: .atomic)
            }
            profiles = catalog.profiles
            selectedProfileId = catalog.profiles.contains { $0.id == catalog.selectedProfileId }
                ? catalog.selectedProfileId
                : catalog.profiles.first?.id ?? AgentProfileDefaults.selectedProfileId
            loadedRootPath = projectService.currentProject?.rootPath
            loadPrompts(from: directoryURL)
        } catch {
            applyBuiltInCatalog()
        }
    }

    func selectProfile(id: String) {
        ensureCurrentProjectIsLoaded()
        guard profiles.contains(where: { $0.id == id }) else { return }
        selectedProfileId = id
        try? persistCatalog()
    }

    func configuration(for profileId: String? = nil) -> MultiAgentRunConfiguration {
        ensureCurrentProjectIsLoaded()
        if let directoryURL = promptDirectoryURL {
            loadPrompts(from: directoryURL)
        }
        let requestedId = profileId ?? selectedProfileId
        guard let profile = profiles.first(where: { $0.id == requestedId }) ?? selectedProfile else {
            return .default
        }

        return MultiAgentRunConfiguration(
            profileId: profile.id,
            profileName: profile.name,
            roles: profile.assistants.map { assistant in
                MultiAgentRoleConfiguration(
                    id: assistant.id,
                    role: assistant.role,
                    assistantName: assistant.name,
                    promptFilePath: promptPath(for: assistant),
                    enabled: assistant.enabled,
                    modelOverride: assistant.modelOverride,
                    instructions: loadedPrompts[assistant.id]
                        ?? AgentProfileDefaults.prompts[assistant.promptFileName]
                        ?? "",
                    outputContract: assistant.role == .securityReviewer
                        ? SecurityReviewPolicy.outputContract
                        : nil
                )
            }
        )
    }

    func prompt(for assistantId: UUID) -> String {
        ensureCurrentProjectIsLoaded()
        return loadedPrompts[assistantId] ?? ""
    }

    func promptFileURL(for assistantId: UUID) throws -> URL {
        ensureCurrentProjectIsLoaded()
        guard let directoryURL = promptDirectoryURL else {
            throw AgentProfileServiceError.projectRootUnavailable
        }
        guard let assistant = profiles
            .flatMap(\.assistants)
            .first(where: { $0.id == assistantId }) else {
            throw AgentProfileServiceError.assistantNotFound
        }
        let fileURL = directoryURL.appendingPathComponent(assistant.promptFileName)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw AgentProfileServiceError.promptFileUnavailable
        }
        return fileURL
    }

    func setAssistantEnabled(id: UUID, enabled: Bool, profileId: String?) throws {
        try updateAssistant(id: id, profileId: profileId) { assistant in
            assistant.enabled = enabled
        }
    }

    func setAssistantModelOverride(id: UUID, modelOverride: String?, profileId: String?) throws {
        try updateAssistant(id: id, profileId: profileId) { assistant in
            assistant.modelOverride = modelOverride
        }
    }

    func moveAssistant(id: UUID, direction: AgentProfileMoveDirection) throws {
        ensureCurrentProjectIsLoaded()
        guard let profileIndex = profiles.firstIndex(where: { $0.id == selectedProfileId }) else {
            throw AgentProfileServiceError.profileNotFound
        }
        guard let assistantIndex = profiles[profileIndex].assistants.firstIndex(where: { $0.id == id }) else {
            throw AgentProfileServiceError.assistantNotFound
        }

        let destinationIndex = direction == .up ? assistantIndex - 1 : assistantIndex + 1
        guard profiles[profileIndex].assistants.indices.contains(destinationIndex) else { return }
        profiles[profileIndex].assistants.swapAt(assistantIndex, destinationIndex)
        try persistCatalog()
    }

    func replacePrompt(for assistantId: UUID, withContentsOf sourceURL: URL) throws {
        ensureCurrentProjectIsLoaded()
        guard let directoryURL = promptDirectoryURL else {
            throw AgentProfileServiceError.projectRootUnavailable
        }
        guard let assistant = profiles
            .flatMap(\.assistants)
            .first(where: { $0.id == assistantId }) else {
            throw AgentProfileServiceError.assistantNotFound
        }
        guard sourceURL.pathExtension.lowercased() == "md",
              let contents = try? String(contentsOf: sourceURL, encoding: .utf8),
              !contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentProfileServiceError.invalidMarkdownFile
        }

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try contents.write(
            to: directoryURL.appendingPathComponent(assistant.promptFileName),
            atomically: true,
            encoding: .utf8
        )
        loadedPrompts[assistant.id] = contents
    }

    private var promptDirectoryURL: URL? {
        guard let rootPath = projectService.currentProject?.rootPath,
              !rootPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: rootPath, isDirectory: true)
            .appendingPathComponent(AgentProfileDefaults.directoryName, isDirectory: true)
    }

    private func ensureCurrentProjectIsLoaded() {
        if loadedRootPath != projectService.currentProject?.rootPath {
            reload()
        }
    }

    private func seedCatalogIfNeeded(at directoryURL: URL) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let manifestURL = directoryURL.appendingPathComponent(AgentProfileDefaults.manifestFileName)
        if !fileManager.fileExists(atPath: manifestURL.path) {
            try encodedCatalog(AgentProfileDefaults.catalog).write(to: manifestURL, options: .atomic)
        }

        for (fileName, prompt) in AgentProfileDefaults.prompts {
            let fileURL = directoryURL.appendingPathComponent(fileName)
            if !fileManager.fileExists(atPath: fileURL.path) {
                try prompt.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
    }

    private func loadPrompts(from directoryURL: URL) {
        loadedPrompts = [:]
        for assistant in profiles.flatMap(\.assistants) {
            let fileURL = directoryURL.appendingPathComponent(assistant.promptFileName)
            if let prompt = try? String(contentsOf: fileURL, encoding: .utf8) {
                loadedPrompts[assistant.id] = prompt
            }
        }
    }

    private func updateAssistant(
        id: UUID,
        profileId: String?,
        update: (inout AgentProfileAssistant) -> Void
    ) throws {
        ensureCurrentProjectIsLoaded()
        let requestedProfileId = profileId ?? selectedProfileId
        guard let profileIndex = profiles.firstIndex(where: { $0.id == requestedProfileId }) else {
            throw AgentProfileServiceError.profileNotFound
        }
        guard let assistantIndex = profiles[profileIndex].assistants.firstIndex(where: { $0.id == id }) else {
            throw AgentProfileServiceError.assistantNotFound
        }

        update(&profiles[profileIndex].assistants[assistantIndex])
        try persistCatalog()
    }

    private func persistCatalog() throws {
        guard let directoryURL = promptDirectoryURL else {
            throw AgentProfileServiceError.projectRootUnavailable
        }
        let catalog = AgentProfileCatalog(selectedProfileId: selectedProfileId, profiles: profiles)
        try encodedCatalog(catalog).write(
            to: directoryURL.appendingPathComponent(AgentProfileDefaults.manifestFileName),
            options: .atomic
        )
    }

    private func encodedCatalog(_ catalog: AgentProfileCatalog) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(catalog)
    }

    private func catalogByAddingMissingBuiltInContent(
        to storedCatalog: AgentProfileCatalog
    ) -> AgentProfileCatalog {
        let storedProfileIds = Set(storedCatalog.profiles.map(\.id))
        let missingProfiles = AgentProfileDefaults.catalog.profiles.filter {
            !storedProfileIds.contains($0.id)
        }
        var profiles = storedCatalog.profiles
        for profileIndex in profiles.indices {
            guard let builtInProfile = AgentProfileDefaults.catalog.profiles.first(where: {
                $0.id == profiles[profileIndex].id
            }) else {
                continue
            }
            profiles[profileIndex].assistants = assistantsByAddingMissingBuiltInContent(
                to: profiles[profileIndex].assistants,
                builtInAssistants: builtInProfile.assistants
            )
        }

        return AgentProfileCatalog(
            selectedProfileId: storedCatalog.selectedProfileId,
            profiles: profiles + missingProfiles
        )
    }

    private func assistantsByAddingMissingBuiltInContent(
        to storedAssistants: [AgentProfileAssistant],
        builtInAssistants: [AgentProfileAssistant]
    ) -> [AgentProfileAssistant] {
        var assistants = storedAssistants
        for (builtInIndex, builtInAssistant) in builtInAssistants.enumerated() {
            guard !assistants.contains(where: { $0.id == builtInAssistant.id }) else {
                continue
            }

            let followingIds = Set(
                builtInAssistants.dropFirst(builtInIndex + 1).map(\.id)
            )
            if let insertionIndex = assistants.firstIndex(where: {
                followingIds.contains($0.id)
            }) {
                assistants.insert(builtInAssistant, at: insertionIndex)
                continue
            }

            let precedingIds = Set(builtInAssistants.prefix(builtInIndex).map(\.id))
            if let previousIndex = assistants.lastIndex(where: {
                precedingIds.contains($0.id)
            }) {
                assistants.insert(builtInAssistant, at: previousIndex + 1)
            } else {
                assistants.append(builtInAssistant)
            }
        }
        return assistants
    }

    private func promptPath(for assistant: AgentProfileAssistant) -> String {
        guard let directoryURL = promptDirectoryURL else {
            return assistant.promptFileName
        }
        return directoryURL.appendingPathComponent(assistant.promptFileName).path
    }

    private func applyBuiltInCatalog() {
        profiles = AgentProfileDefaults.catalog.profiles
        selectedProfileId = AgentProfileDefaults.catalog.selectedProfileId
        loadedPrompts = Dictionary(uniqueKeysWithValues: profiles.flatMap(\.assistants).compactMap { assistant in
            AgentProfileDefaults.prompts[assistant.promptFileName].map { (assistant.id, $0) }
        })
    }
}
