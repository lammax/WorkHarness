//
// RunEvent.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation

struct RunEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let runId: UUID
    let type: RunEventType
    var message: String
    var metadata: [String: String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        runId: UUID,
        type: RunEventType,
        message: String,
        metadata: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.runId = runId
        self.type = type
        self.message = message
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

enum RunEventType: String, Codable, CaseIterable, Equatable {
    case runCreated
    case userMessage
    case assistantMessage
    case agentStarted
    case agentFinished
    case providerRequestStarted
    case providerStreamDelta
    case providerRequestFinished
    case providerRequestFailed
    case toolCall
    case toolCallRequested
    case toolCallStarted
    case toolCallFinished
    case toolCallFailed
    case toolResult
    case artifactCreated
    case fileChanged
    case approvalRequested
    case approvalGranted
    case approvalRejected
    case contextBuilt
    case contextCompacted
    case memorySaved
    case validationStarted
    case validationFinished
    case error
    case finalSummary
    case runInterrupted
    case runResumed
    case runRestarted
    case runCompleted
    case runCancelled
    case runFailed

    var label: String {
        switch self {
        case .runCreated: "Run Created"
        case .userMessage: "User"
        case .assistantMessage: "Assistant"
        case .agentStarted: "Agent Started"
        case .agentFinished: "Agent Finished"
        case .providerRequestStarted: "Provider Started"
        case .providerStreamDelta: "Provider Delta"
        case .providerRequestFinished: "Provider Finished"
        case .providerRequestFailed: "Provider Failed"
        case .toolCall: "Tool Call"
        case .toolCallRequested: "Tool Requested"
        case .toolCallStarted: "Tool Started"
        case .toolCallFinished: "Tool Finished"
        case .toolCallFailed: "Tool Failed"
        case .toolResult: "Tool Result"
        case .artifactCreated: "Artifact Created"
        case .fileChanged: "File Changed"
        case .approvalRequested: "Approval Requested"
        case .approvalGranted: "Approval Granted"
        case .approvalRejected: "Approval Rejected"
        case .contextBuilt: "Context Built"
        case .contextCompacted: "Context Compacted"
        case .memorySaved: "Memory Saved"
        case .validationStarted: "Validation Started"
        case .validationFinished: "Validation Finished"
        case .error: "Error"
        case .finalSummary: "Summary"
        case .runInterrupted: "Run Interrupted"
        case .runResumed: "Run Resumed"
        case .runRestarted: "Run Restarted"
        case .runCompleted: "Run Completed"
        case .runCancelled: "Run Cancelled"
        case .runFailed: "Run Failed"
        }
    }
}
