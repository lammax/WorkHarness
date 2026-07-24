//
// MobileAutomationTool.swift
// WorkHarness
//
// Created by Auto (Codex) on 24.07.2026.
//

import Foundation

@MainActor
struct MobileAutomationTool: ToolProtocol {
    let id: String
    let displayName: String
    let description: String
    let permission: ToolPermission
    let inputSchema: [ToolInputField]

    static let approvedTools: [MobileAutomationTool] = [
        MobileAutomationTool(
            id: "mobile.health",
            displayName: "Mobile Automation Health",
            description: "Check Claude in Mobile, Xcode, Simulator, Appium, and WebDriverAgent availability.",
            permission: .readOnly,
            inputSchema: []
        ),
        MobileAutomationTool(
            id: "mobile.device",
            displayName: "Mobile Device",
            description: "List or select Claude in Mobile devices and inspect the active target.",
            permission: .shell,
            inputSchema: metaToolSchema(
                actions: "list, set, set_target, get_target, enable_module, disable_module, list_modules"
            )
        ),
        MobileAutomationTool(
            id: "mobile.app",
            displayName: "Mobile App",
            description: "Launch, stop, install, or list applications through Claude in Mobile.",
            permission: .shell,
            inputSchema: metaToolSchema(actions: "launch, stop, install, list")
        ),
        MobileAutomationTool(
            id: "mobile.screen",
            displayName: "Mobile Screen",
            description: "Capture or annotate a screenshot through Claude in Mobile.",
            permission: .readOnly,
            inputSchema: metaToolSchema(actions: "capture, annotate")
        ),
        MobileAutomationTool(
            id: "mobile.ui",
            displayName: "Mobile UI",
            description: "Inspect, locate, wait for, assert, or interact with accessible UI elements through Claude in Mobile.",
            permission: .shell,
            inputSchema: metaToolSchema(
                actions: "tree, find, find_tap, tap_text, analyze, wait, assert_visible, assert_gone"
            )
        ),
        MobileAutomationTool(
            id: "mobile.input",
            displayName: "Mobile Input",
            description: "Tap, swipe, type, or send a key through Claude in Mobile.",
            permission: .shell,
            inputSchema: metaToolSchema(actions: "tap, double_tap, long_press, swipe, text, key")
        )
    ]

    func approvalRequirement(
        for arguments: [String: String],
        context: ToolExecutionContext
    ) -> ToolApprovalRequirement? {
        guard permission.requiresDefaultApproval else { return nil }
        let action = arguments["action"] ?? "unknown"
        return ToolApprovalRequirement(
            title: "Approve mobile automation",
            summary: "\(displayName): \(action)",
            mode: .askBeforeShell
        )
    }

    private static func metaToolSchema(actions: String) -> [ToolInputField] {
        [
            ToolInputField(
                name: "action",
                description: "Claude in Mobile action. Supported actions: \(actions).",
                required: true
            ),
            ToolInputField(
                name: "argumentsJSON",
                description: "Optional JSON object string containing all additional Claude in Mobile arguments.",
                required: false
            )
        ]
    }
}
