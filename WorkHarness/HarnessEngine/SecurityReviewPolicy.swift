//
// SecurityReviewPolicy.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.08.2026.
//

import Foundation

enum SecurityReviewSeverity: String, Codable, CaseIterable, Equatable {
    case none
    case low
    case medium
    case high
    case critical

    var blocksCommit: Bool {
        self == .critical || self == .high
    }
}

enum SecurityReviewVerdict: String, Codable, Equatable {
    case clean
    case warning
    case block
}

struct SecurityReviewDecision: Codable, Equatable {
    var verdict: SecurityReviewVerdict
    var severity: SecurityReviewSeverity
    var finding: String
    var location: String
    var remediation: String

    var blocksCommit: Bool {
        verdict == .block || severity.blocksCommit
    }

    var auditStatus: String {
        if blocksCommit { return "blocked" }
        return verdict == .warning || severity == .medium || severity == .low
            ? "warning"
            : "passed"
    }

    var feedback: String {
        guard blocksCommit else { return "" }
        return "Fix security finding: \(finding) at \(location). \(remediation)"
    }
}

enum SecurityReviewPolicyError: LocalizedError, Equatable {
    case invalidResponse
    case inconsistentVerdict

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Security review must return the required compact JSON object."
        case .inconsistentVerdict:
            "Security review verdict and severity are inconsistent."
        }
    }
}

struct SecurityReviewPolicy {
    static let outputContract = AgentOutputContract(
        requiredKeys: ["verdict", "severity", "finding", "location", "remediation"],
        allowedValues: [
            "verdict": SecurityReviewVerdict.allCases.map(\.rawValue),
            "severity": SecurityReviewSeverity.allCases.map(\.rawValue)
        ]
    )

    func decision(from output: String) throws -> SecurityReviewDecision {
        guard let data = output.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let decision = try? JSONDecoder().decode(SecurityReviewDecision.self, from: data) else {
            throw SecurityReviewPolicyError.invalidResponse
        }
        guard (decision.verdict == .block) == decision.severity.blocksCommit,
              decision.verdict != .clean || decision.severity == .none else {
            throw SecurityReviewPolicyError.inconsistentVerdict
        }
        return decision
    }
}

extension SecurityReviewVerdict: CaseIterable {}
