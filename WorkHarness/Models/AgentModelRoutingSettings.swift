//
// AgentModelRoutingSettings.swift
// WorkHarness
//
// Created by Auto (Codex) on 29.07.2026.
//

import Foundation

struct AgentModelRoutingSettings: Codable, Equatable {
    var isEnabled: Bool
    var fastModelId: String
    var fallbackModelId: String
    var promptLengthThreshold: Int
}

struct AgentModelRoutingDecision: Equatable {
    enum Route: String, Equatable {
        case manual
        case fast
        case fallback
    }

    var selectedModelId: String?
    var route: Route
    var reason: String
    var promptLength: Int
    var promptLengthThreshold: Int?
    var matchedKeyword: String?

    var usesAutomaticRouting: Bool {
        route != .manual
    }
}
