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
            static let sectionSpacing: CGFloat = 18
        }

        enum Tabs {
            static let title = "Settings sections"
            static let executionTitle = "Execution & Providers"
            static let applicationTitle = "Application"
            static let ragTitle = "RAG"
            static let executionIcon = "play.circle"
            static let applicationIcon = "gearshape"
            static let ragIcon = "books.vertical"
        }

        enum ExecutionBackend {
            static let title = "Execution Backend"
            static let pickerTitle = "Backend for the next Run"
            static let nextRunLabel = "Used by new Runs"
            static let icon = "play.circle"
            static let selectedIcon = "checkmark.circle.fill"
            static let spacing: CGFloat = 12
            static let detailSpacing: CGFloat = 8
            static let detailTextSpacing: CGFloat = 3
            static let padding: CGFloat = 12
            static let cornerRadius: CGFloat = 8
        }

        enum AgentRuntime {
            static let pickerTitle = "Agent runtime for the next Run"
            static let modelPickerTitle = "Cursor model"
            static let noneTitle = "No ACP agent"
            static let icon = "person.crop.circle.badge.checkmark"
        }

        enum AppSettings {
            static let title = "Application Settings"
            static let safetyModeTitle = "Safety mode"
            static let mcpBasePathTitle = "MCP server base path"
            static let localLLMEndpointTitle = "Local LLM endpoint"
            static let localLLMModelTitle = "Local LLM model"
            static let remoteControlTitle = "Remote Control"
            static let remoteControlEnabledTitle = "Enable localhost API"
            static let remoteControlAllowLANTitle = "Allow local network access"
            static let remoteControlPortTitle = "API port"
            static let remoteControlTokenTitle = "Bearer token"
            static let remoteControlTokenPlaceholder = "Leave empty to generate a local token"
            static let maxInputTokensTitle = "Max input tokens"
            static let maxOutputTokensTitle = "Max output tokens"
            static let saveButtonTitle = "Save"
            static let revertButtonTitle = "Revert"
            static let restoreDefaultsButtonTitle = "Restore Defaults"
            static let savedStatus = "Saved"
            static let unsavedStatus = "Unsaved changes"
            static let mcpBasePathPlaceholder = "/Users/me/MCP_server"
            static let localLLMEndpointPlaceholder = "http://127.0.0.1:3007/mcp"
            static let localLLMModelPlaceholder = "local-private"
            static let spacing: CGFloat = 12
            static let rowSpacing: CGFloat = 10
            static let fieldSpacing: CGFloat = 18
            static let padding: CGFloat = 12
            static let cornerRadius: CGFloat = 8
            static let tokenRange = 256...200_000
            static let tokenStep = 256
        }

        enum ProviderList {
            static let title = "Providers"
            static let width: CGFloat = 280
            static let spacing: CGFloat = 10
        }

        enum RAGSettings {
            static let title = "Project Knowledge (RAG)"
            static let icon = "books.vertical"
            static let sourceLabel = "MCP Server · 127.0.0.1:3003"
            static let answerModeTitle = "RAG for new Runs"
            static let chunkingTitle = "Indexed chunk strategy"
            static let retrievalTitle = "Retrieval mode"
            static let filterTitle = "Relevance filter"
            static let topKBeforeTitle = "Before filter"
            static let topKAfterTitle = "After filter"
            static let thresholdTitle = "Similarity threshold"
            static let spacing: CGFloat = 12
            static let controlSpacing: CGFloat = 6
            static let fieldSpacing: CGFloat = 18
            static let padding: CGFloat = 12
            static let cornerRadius: CGFloat = 8
            static let topKBeforeRange = 1...30
            static let topKAfterRange = 1...20
            static let thresholdRange = 0.0...1.0
            static let thresholdStep = 0.01
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
            static let mcpBacked = "MCP-backed"
            static let internalProvider = "Internal"
            static let local = "Local"
            static let remote = "Remote"
        }

        enum EmptyState {
            static let title = "No Providers"
            static let icon = "antenna.radiowaves.left.and.right.slash"
            static let description = "Register a provider to make it available here."
        }
    }
}
