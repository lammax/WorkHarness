//
// SettingsTestingView.swift
// WorkHarness
//
// Created by Auto (Codex) on 24.07.2026.
//

import SwiftUI

extension MainScreen {
    struct SettingsTestingView: View {
        typealias Design = SettingsPageDesign.Testing

        @Bindable var viewModel: SettingsPageViewModel

        var body: some View {
            VStack(alignment: .leading, spacing: Design.sectionSpacing) {
                HStack {
                    Label(Design.title, systemImage: Design.icon)
                        .font(.headline)

                    Spacer()

                    Button(Design.reloadButtonTitle) {
                        viewModel.reloadTestingConfiguration()
                    }
                }

                Text(Design.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent(Design.directoryTitle) {
                    Text(viewModel.testingConfigurationDirectoryPath)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }

                Divider()
                testingTarget
                Divider()
                testingEnvironment
                Divider()

                Text(Design.scenariosTitle)
                    .font(.headline)

                VStack(spacing: Design.scenarioSpacing) {
                    ForEach(Array(viewModel.smokeScenarios.enumerated()), id: \.element.id) {
                        index,
                        scenario in
                        smokeScenarioRow(
                            scenario,
                            index: index,
                            scenarioCount: viewModel.smokeScenarios.count
                        )
                    }
                }
            }
            .padding(Design.padding)
            .background(
                .thinMaterial,
                in: RoundedRectangle(cornerRadius: Design.cornerRadius)
            )
        }

        private var testingEnvironment: some View {
            VStack(alignment: .leading, spacing: Design.fieldSpacing) {
                HStack {
                    Text(Design.diagnosticsTitle)
                        .font(.headline)

                    Spacer()

                    Text(viewModel.testingEnvironmentStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(
                        viewModel.isCheckingTestingEnvironment
                            ? Design.diagnosticsCheckingTitle
                            : Design.diagnosticsButtonTitle
                    ) {
                        viewModel.checkTestingEnvironment()
                    }
                    .disabled(viewModel.isCheckingTestingEnvironment)
                }

                if let diagnostics = viewModel.testingEnvironmentDiagnostics {
                    ForEach(diagnostics.checks) { check in
                        HStack(alignment: .top, spacing: Design.rowSpacing) {
                            Image(systemName: diagnosticIcon(for: check.status))
                                .foregroundStyle(diagnosticColor(for: check.status))

                            VStack(alignment: .leading, spacing: Design.textSpacing) {
                                Text(check.title)
                                    .fontWeight(.semibold)
                                Text(check.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                if let remediation = check.remediation {
                                    Text(remediation)
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            }
        }

        private func diagnosticIcon(
            for status: TestingDiagnosticStatus
        ) -> String {
            switch status {
            case .ready: Design.diagnosticIconReady
            case .warning: Design.diagnosticIconWarning
            case .unavailable: Design.diagnosticIconUnavailable
            }
        }

        private func diagnosticColor(
            for status: TestingDiagnosticStatus
        ) -> Color {
            switch status {
            case .ready: Design.diagnosticReadyColor
            case .warning: Design.diagnosticWarningColor
            case .unavailable: Design.diagnosticUnavailableColor
            }
        }

        private var testingTarget: some View {
            VStack(alignment: .leading, spacing: Design.fieldSpacing) {
                HStack {
                    Text(Design.targetTitle)
                        .font(.headline)

                    Spacer()

                    Text(viewModel.testingTargetStatus)
                        .font(.caption)
                        .foregroundStyle(
                            viewModel.hasUnsavedTestingTargetChanges ? .orange : .secondary
                        )

                    Button(Design.revertButtonTitle) {
                        viewModel.revertTestingTarget()
                    }
                    .disabled(!viewModel.hasUnsavedTestingTargetChanges)

                    Button(Design.saveButtonTitle) {
                        viewModel.saveTestingTarget()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.hasUnsavedTestingTargetChanges)
                }

                Picker(Design.platformTitle, selection: $viewModel.testingPlatform) {
                    ForEach(SmokeTestPlatform.allCases, id: \.self) { platform in
                        Text(platform.title).tag(platform)
                    }
                }
                .pickerStyle(.segmented)

                TestingTargetField(
                    title: Design.xcodeContainerTitle,
                    placeholder: "App.xcodeproj",
                    text: $viewModel.testingXcodeContainerPath
                )
                TestingTargetField(
                    title: Design.schemeTitle,
                    placeholder: "App",
                    text: $viewModel.testingScheme
                )
                TestingTargetField(
                    title: Design.bundleIdentifierTitle,
                    placeholder: "com.example.app",
                    text: $viewModel.testingBundleIdentifier
                )
                TestingTargetField(
                    title: Design.deviceNameTitle,
                    placeholder: "iPhone 16 Pro",
                    text: $viewModel.testingDeviceName
                )
                TestingTargetField(
                    title: Design.buildCommandTitle,
                    placeholder: "xcodebuild build …",
                    text: $viewModel.testingBuildCommand
                )
                TestingTargetField(
                    title: Design.codeTestCommandTitle,
                    placeholder: "xcodebuild test …",
                    text: $viewModel.testingCodeTestCommand
                )
            }
        }

        private func smokeScenarioRow(
            _ scenario: SmokeScenario,
            index: Int,
            scenarioCount: Int
        ) -> some View {
            HStack(alignment: .top, spacing: Design.rowSpacing) {
                Text("\(index + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: Design.orderWidth)

                Toggle(
                    isOn: Binding(
                        get: { scenario.enabled },
                        set: { viewModel.setSmokeScenarioEnabled(id: scenario.id, enabled: $0) }
                    )
                ) {
                    VStack(alignment: .leading, spacing: Design.textSpacing) {
                        Text(scenario.name)
                            .fontWeight(.semibold)
                        Text(scenario.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(scenario.promptFileName)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Text(viewModel.smokeScenarioPreview(for: scenario.id))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(Design.promptLineLimit)
                    }
                }
                .toggleStyle(.checkbox)

                Spacer()

                VStack(spacing: Design.buttonSpacing) {
                    HStack {
                        Button {
                            viewModel.moveSmokeScenario(id: scenario.id, direction: .up)
                        } label: {
                            Image(systemName: Design.moveUpIcon)
                        }
                        .disabled(index == 0)

                        Button {
                            viewModel.moveSmokeScenario(id: scenario.id, direction: .down)
                        } label: {
                            Image(systemName: Design.moveDownIcon)
                        }
                        .disabled(index == scenarioCount - 1)
                    }

                    HStack {
                        Button(Design.openScenarioButtonTitle) {
                            viewModel.openSmokeScenario(for: scenario.id)
                        }

                        Button(Design.loadScenarioButtonTitle) {
                            viewModel.presentSmokeScenarioImporter(for: scenario.id)
                        }
                    }
                }
            }
            .padding(Design.rowPadding)
            .background(
                Color.secondary.opacity(Design.rowBackgroundOpacity),
                in: RoundedRectangle(cornerRadius: Design.rowCornerRadius)
            )
        }
    }

    private struct TestingTargetField: View {
        let title: String
        let placeholder: String
        @Binding var text: String

        var body: some View {
            LabeledContent(title) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .textSelection(.enabled)
            }
        }
    }
}
