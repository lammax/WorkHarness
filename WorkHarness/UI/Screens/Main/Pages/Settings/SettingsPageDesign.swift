//
// SettingsPageDesign.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import CoreGraphics

extension MainScreen {
    enum SettingsPageDesign {
        enum Layout {
            static let spacing: CGFloat = 0
        }

        enum Header {
            static let title = "Settings"
            static let activeProviderPrefix = "Active provider: "
            static let spacing: CGFloat = 5
            static let padding: CGFloat = 16
        }

        enum Content {
            static let columnSpacing: CGFloat = 16
            static let padding: CGFloat = 16
        }

        enum ProviderList {
            static let title = "Providers"
            static let width: CGFloat = 280
            static let spacing: CGFloat = 10
        }

        enum ProviderRow {
            static let activeIcon = "checkmark.circle.fill"
            static let inactiveIcon = "circle"
            static let iconSize: CGFloat = 18
            static let spacing: CGFloat = 10
            static let textSpacing: CGFloat = 3
            static let padding: CGFloat = 10
            static let cornerRadius: CGFloat = 8
        }

        enum ProviderDetails {
            static let spacing: CGFloat = 20
            static let titleSpacing: CGFloat = 4
        }

        enum CapabilityList {
            static let title = "Capabilities"
            static let spacing: CGFloat = 4
        }

        enum CapabilityRow {
            static let spacing: CGFloat = 12
            static let titleWidth: CGFloat = 150
            static let verticalPadding: CGFloat = 3
        }

        enum Capability {
            static let streaming = "Streaming"
            static let toolCalls = "Tool calls"
            static let fileEditing = "File editing"
            static let shellExecution = "Shell execution"
            static let vision = "Vision"
            static let embeddings = "Embeddings"
            static let reasoning = "Reasoning mode"
            static let localExecution = "Local execution"
            static let approvals = "Approvals"
            static let mcp = "MCP"
            static let contextWindow = "Context window"
            static let costModel = "Cost model"
            static let models = "Models"
        }

        enum ProviderFallback {
            static let noActiveProvider = "No Provider"
            static let notAvailable = "N/A"
            static let yes = "Yes"
            static let no = "No"
            static let tokensSuffix = "tokens"
            static let listSeparator = ", "
        }

        enum EmptyState {
            static let title = "No Providers"
            static let icon = "antenna.radiowaves.left.and.right.slash"
            static let description = "Register a provider to make it available here."
        }
    }
}
