//
// AppNavigationViewModel.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Observation

@MainActor
@Observable
final class AppNavigationViewModel {
    var selectedSection: NavigationSection = .chat

    func showChat() {
        selectedSection = .chat
    }

    func selectRun(_ run: Run, chatViewModel: ChatViewModel) {
        chatViewModel.selectRun(run)
        showChat()
    }
}
