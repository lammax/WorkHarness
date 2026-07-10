//
// MemoryPageViewModel.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation
import Observation

extension MainScreen {
    @MainActor
    @Observable
    final class MemoryPageViewModel {
        private let memoryService: MemoryServiceProtocol
        private let projectService: ProjectServiceProtocol

        var draftContent = ""
        private(set) var errorMessage: String?

        init(memoryService: MemoryServiceProtocol, projectService: ProjectServiceProtocol) {
            self.memoryService = memoryService
            self.projectService = projectService
        }

        var currentProject: Project? {
            projectService.currentProject
        }

        var items: [MemoryItem] {
            guard let projectId = currentProject?.id else { return [] }
            return memoryService.items(for: projectId)
        }

        func saveDraft() {
            guard let projectId = currentProject?.id else {
                errorMessage = MemoryPageDesign.Error.noProject
                return
            }

            do {
                _ = try memoryService.saveProjectMemory(content: draftContent, projectId: projectId, runId: nil)
                draftContent = ""
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        func remove(item: MemoryItem) {
            memoryService.removeMemory(id: item.id)
            errorMessage = nil
        }
    }
}
