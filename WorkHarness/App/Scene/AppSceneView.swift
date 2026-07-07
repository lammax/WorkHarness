//
// AppSceneView.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

struct AppSceneView: View {
    @Bindable var viewModel: AppSceneViewModel

    var body: some View {
        if let activeScreen = viewModel.activeScreen {
            activeScreen.content
        } else {
            EmptyView()
        }
    }
}
