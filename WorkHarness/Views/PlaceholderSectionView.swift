//
// PlaceholderSectionView.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

struct PlaceholderSectionView: View {
    let section: NavigationSection

    var body: some View {
        ContentUnavailableView {
            Label(AppDesign.Navigation.title(for: section), systemImage: AppDesign.Navigation.icon(for: section))
        } description: {
            Text(AppDesign.Placeholder.description)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
