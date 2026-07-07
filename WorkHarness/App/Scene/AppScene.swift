//
// AppScene.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

@MainActor
final class AppScene: AppSceneProtocol {
    let viewModel: AppSceneViewModel

    init(rootScreen: any BaseScreenProtocol) {
        let viewModel = AppSceneViewModel()
        viewModel.push(screen: rootScreen)
        self.viewModel = viewModel
    }

    var content: AnyView {
        AnyView(AppSceneView(viewModel: viewModel))
    }
}
