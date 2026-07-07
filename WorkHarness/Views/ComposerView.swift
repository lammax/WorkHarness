//
// ComposerView.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

struct ComposerView: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: AppDesign.Composer.spacing) {
            TextField(AppDesign.Composer.placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(AppDesign.Composer.minLineLimit...AppDesign.Composer.maxLineLimit)
                .padding(AppDesign.Composer.fieldPadding)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppDesign.Composer.cornerRadius))
                .onSubmit(submit)

            Button(action: submit) {
                Image(systemName: isSending ? AppDesign.Composer.sendingIcon : AppDesign.Composer.sendIcon)
                    .frame(width: AppDesign.Composer.buttonIconSize, height: AppDesign.Composer.buttonIconSize)
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            .help(AppDesign.Composer.sendHelp)
        }
    }

    private func submit() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isSending else { return }
        onSend()
    }
}
