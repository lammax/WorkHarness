//
// PagesControlView.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

struct PagesControlView: View {
    @Bindable var viewModel: PagesViewModel

    var body: some View {
        ZStack {
            ForEach(Array(viewModel.pages.enumerated()), id: \.offset) { item in
                if item.offset + 1 + (viewModel.isHidePreviousPage ? 0 : 1) >= viewModel.pages.count {
                    item.element.content
                        .disabled(item.offset + 2 == viewModel.pages.count)
                        .opacity(item.offset + 1 == viewModel.pages.count ? viewModel.alpha : 1)
                }
            }
        }
    }
}
