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
        let contextAttachments: [RunContextAttachment]
        let isSending: Bool
        let onAttach: () -> Void
        let onRemoveAttachment: (RunContextAttachment) -> Void
        let onSend: () -> Void
        let onStop: () -> Void

        var body: some View {
            VStack(alignment: .trailing, spacing: Design.spacing) {
                Picker(Design.modeLabel, selection: $mode) {
                    Text(Design.simpleModeLabel).tag(RunMode.simpleChat)
                    Text(Design.multiAgentModeLabel).tag(RunMode.multiAgent)
                }
                .pickerStyle(.segmented)

                if !contextAttachments.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: Design.Attachment.spacing) {
                            ForEach(contextAttachments) { attachment in
                                AttachmentChip(
                                    attachment: attachment,
                                    onRemove: { onRemoveAttachment(attachment) }
                                )
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .bottom, spacing: Design.spacing) {
                    Button(action: onAttach) {
                        Image(systemName: Design.attachIcon)
                            .frame(width: Design.buttonIconSize, height: Design.buttonIconSize)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSending)
                    .help(Design.attachHelp)
                    .accessibilityLabel(Design.attachHelp)

                    TextField(Design.placeholder, text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(Design.minLineLimit...Design.maxLineLimit)
                        .padding(Design.fieldPadding)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Design.cornerRadius))
                        .onSubmit(submit)

                    if isSending {
                        Button(action: onStop) {
                            Image(systemName: Design.stopIcon)
                                .frame(width: Design.buttonIconSize, height: Design.buttonIconSize)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Design.stopColor)
                        .help(Design.stopHelp)
                        .accessibilityLabel(Design.stopHelp)
                    } else {
                        Button(action: submit) {
                            Image(systemName: Design.sendIcon)
                                .frame(width: Design.buttonIconSize, height: Design.buttonIconSize)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .help(Design.sendHelp)
                    }
                }
            }
        }

        private func submit() {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isSending else { return }
            onSend()
        }
    }

    private struct AttachmentChip: View {
        typealias Design = ComposerViewDesign.Attachment

        let attachment: RunContextAttachment
        let onRemove: () -> Void

        var body: some View {
            HStack(spacing: Design.contentSpacing) {
                Image(systemName: Design.fileIcon)
                    .foregroundStyle(.secondary)

                Text(attachment.name)
                    .font(.caption)
                    .lineLimit(Design.nameLineLimit)

                Button(action: onRemove) {
                    Image(systemName: Design.removeIcon)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help(Design.removeHelp)
                .accessibilityLabel(Design.removeHelp)
            }
            .padding(.horizontal, Design.horizontalPadding)
            .padding(.vertical, Design.verticalPadding)
            .background(.thinMaterial, in: Capsule())
        }
    }
}
