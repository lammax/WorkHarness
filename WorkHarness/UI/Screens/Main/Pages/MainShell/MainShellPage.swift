//
// MainShellPage.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

extension MainScreen {
    final class MainShellPage: BasePageProtocol {
        let content: AnyView

        init(screenModel: MainScreenViewModel) {
            self.content = AnyView(MainShellPageView(screenModel: screenModel))
        }
    }
}
