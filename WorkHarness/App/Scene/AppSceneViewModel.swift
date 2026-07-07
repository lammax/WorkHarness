//
// AppSceneViewModel.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Observation

@MainActor
@Observable
final class AppSceneViewModel {
    private(set) var screens: [any BaseScreenProtocol] = []

    var activeScreen: (any BaseScreenProtocol)? {
        screens.last
    }

    func push(screen: any BaseScreenProtocol) {
        screens.append(screen)
        screen.onShown()
    }

    func popScreen() {
        guard let screen = screens.popLast() else { return }
        screen.onClosed()
    }
}
