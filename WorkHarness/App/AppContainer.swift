//
// AppContainer.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppContainer {
    let runRepository: InMemoryRunRepository
    let provider: AIProvider
    let runRecorder: RunRecorder
    let harnessEngine: HarnessEngine
    let chatViewModel: ChatViewModel
    let navigationViewModel: AppNavigationViewModel

    convenience init() {
        self.init(provider: MockAIProvider())
    }

    init(provider: AIProvider) {
        let runRepository = InMemoryRunRepository()
        let runRecorder = RunRecorder(repository: runRepository)
        let harnessEngine = HarnessEngine(repository: runRepository, recorder: runRecorder, provider: provider)

        self.runRepository = runRepository
        self.provider = provider
        self.runRecorder = runRecorder
        self.harnessEngine = harnessEngine
        self.chatViewModel = ChatViewModel(repository: runRepository, harnessEngine: harnessEngine)
        self.navigationViewModel = AppNavigationViewModel()
    }
}
