//
// MemoryPageView.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import SwiftUI

extension MainScreen {
    struct MemoryPageView: View {
        typealias Design = MemoryPageDesign

        @Bindable var viewModel: MemoryPageViewModel

        var body: some View {
            VStack(alignment: .leading, spacing: Design.Layout.spacing) {
                header
                Divider()
                composer

                if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        Design.EmptyState.title,
                        systemImage: Design.EmptyState.icon,
                        description: Text(Design.EmptyState.description)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Design.Layout.spacing) {
                            ForEach(viewModel.items) { item in
                                memoryRow(item)
                            }
                        }
                        .padding(Design.Layout.padding)
                    }
                }
            }
            .padding(.top, Design.Layout.padding)
        }

        private var header: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(Design.Header.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(viewModel.currentProject.map { "\(Design.Header.projectPrefix)\($0.name)" } ?? Design.Header.noProject)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Design.Header.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Design.Layout.padding)
        }

        private var composer: some View {
            VStack(alignment: .leading, spacing: Design.Composer.spacing) {
                TextEditor(text: $viewModel.draftContent)
                    .frame(minHeight: Design.Composer.editorHeight)
                    .overlay(RoundedRectangle(cornerRadius: Design.Layout.cornerRadius).stroke(.quaternary))

                HStack {
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Spacer()

                    Button(Design.Composer.save) {
                        viewModel.saveDraft()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.currentProject == nil)
                }
            }
            .padding(.horizontal, Design.Layout.padding)
        }

        private func memoryRow(_ item: MemoryItem) -> some View {
            HStack(alignment: .top, spacing: Design.Row.spacing) {
                Text(item.content)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)

                Button {
                    viewModel.remove(item: item)
                } label: {
                    Image(systemName: Design.Row.delete)
                }
                .buttonStyle(.borderless)
                .help("Delete memory")
            }
            .padding(Design.Row.padding)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: Design.Layout.cornerRadius))
        }
    }
}
