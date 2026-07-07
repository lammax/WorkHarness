//
// PlaceholderPageView.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

extension MainScreen {
    struct PlaceholderPageView: View {
        typealias Design = PlaceholderPageDesign

        @Bindable var viewModel: PlaceholderPageViewModel

        var body: some View {
            ContentUnavailableView {
                Label(viewModel.title, systemImage: viewModel.icon)
            } description: {
                Text(Design.description)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
