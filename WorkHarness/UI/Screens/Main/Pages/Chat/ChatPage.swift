//
// ChatPage.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

extension MainScreen {
    final class ChatPage: BasePageProtocol {
        let content: AnyView

        init(screenModel: MainScreenViewModel) {
            self.content = AnyView(ChatPageView(viewModel: screenModel.chatPageViewModel))
        }
    }
}
