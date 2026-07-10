//
// ComposerView.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

extension MainScreen {
    struct ComposerView: View {
        typealias Design = ComposerViewDesign

        @Binding var text: String
        @Binding var mode: RunMode
        let isSending: Bool
        let onSend: () -> Void

        var body: some View {
            VStack(alignment: .trailing, spacing: Design.spacing) {
                Picker(Design.modeLabel, selection: $mode) {
                    Text(Design.simpleModeLabel).tag(RunMode.simpleChat)
                    Text(Design.multiAgentModeLabel).tag(RunMode.multiAgent)
                }
                .pickerStyle(.segmented)

                HStack(alignment: .bottom, spacing: Design.spacing) {
                TextField(Design.placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(Design.minLineLimit...Design.maxLineLimit)
                    .padding(Design.fieldPadding)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Design.cornerRadius))
                    .onSubmit(submit)

                Button(action: submit) {
                    Image(systemName: isSending ? Design.sendingIcon : Design.sendIcon)
                        .frame(width: Design.buttonIconSize, height: Design.buttonIconSize)
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                .help(Design.sendHelp)
                }
            }
        }

        private func submit() {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isSending else { return }
            onSend()
        }
    }
}
