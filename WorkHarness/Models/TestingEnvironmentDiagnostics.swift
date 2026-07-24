//
// TestingEnvironmentDiagnostics.swift
// WorkHarness
//
// Created by Auto (Codex) on 24.07.2026.
//

import Foundation

enum TestingDiagnosticStatus: String, Codable, Equatable {
    case ready
    case warning
    case unavailable
}

struct TestingDiagnosticCheck: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var status: TestingDiagnosticStatus
    var message: String
    var remediation: String?
}

struct TestingEnvironmentDiagnostics: Codable, Equatable {
    var checkedAt: Date
    var checks: [TestingDiagnosticCheck]

    var canStartSmokeTests: Bool {
        checks.first(where: { $0.id == "claudeInMobile" })?.status == .ready
            && checks.first(where: { $0.id == "xcode" })?.status == .ready
            && checks.first(where: { $0.id == "simulator" })?.status == .ready
    }
}
