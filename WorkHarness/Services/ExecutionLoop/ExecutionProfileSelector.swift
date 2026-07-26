//
// ExecutionProfileSelector.swift
// WorkHarness
//
// Created by Auto (Codex) on 26.07.2026.
//

import Foundation

struct ExecutionProfileSelector {
    func profileId(for task: ExecutionTask) -> String {
        switch task.category {
        case .bug:
            "bug-fix"
        case .research:
            "research"
        case .documentation, .feature, .refactoring, .security, .tests:
            "implementation"
        }
    }
}

