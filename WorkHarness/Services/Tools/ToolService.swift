//
// ToolService.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

@MainActor
final class ToolService: ToolServiceProtocol {
    private let registry: ToolRegistry
    private let mcpClient: MCPToolClientProtocol
    private let approvalService: ApprovalServiceProtocol
    private let recorder: RunRecorder

    init(
        registry: ToolRegistry,
        mcpClient: MCPToolClientProtocol,
        approvalService: ApprovalServiceProtocol,
        recorder: RunRecorder
    ) {
        self.registry = registry
        self.mcpClient = mcpClient
        self.approvalService = approvalService
        self.recorder = recorder
    }

    var availableTools: [ToolDefinition] {
        registry.availableTools
    }

    func execute(_ request: ToolExecutionRequest) async throws -> ToolResult {
        let tool = try registry.tool(id: request.toolId)
        let context = ToolExecutionContext(runId: request.runId, projectRootPath: request.projectRootPath)
        let metadata = toolMetadata(for: request, tool: tool)

        recorder.record(
            runId: request.runId,
            type: .toolCallRequested,
            message: tool.displayName,
            metadata: metadata
        )

        if let approvalRequirement = tool.approvalRequirement(for: request.arguments, context: context) {
            let approval = try approvalService.requestApproval(
                runId: request.runId,
                title: approvalRequirement.title,
                summary: approvalRequirement.summary,
                mode: approvalRequirement.mode
            )
            if approval.status == .granted {
                return try await invokeMCP(request, tool: tool, metadata: metadata)
            }

            return ToolResult(
                toolId: tool.id,
                status: .approvalRequired,
                output: approvalRequirement.summary,
                metadata: metadata.merging([
                    "approvalRequestId": approval.id.uuidString
                ]) { _, new in new }
            )
        }

        return try await invokeMCP(request, tool: tool, metadata: metadata)
    }

    func executeAwaitingApproval(_ request: ToolExecutionRequest) async throws -> ToolResult {
        let tool = try registry.tool(id: request.toolId)
        let context = ToolExecutionContext(runId: request.runId, projectRootPath: request.projectRootPath)
        let metadata = toolMetadata(for: request, tool: tool)

        recorder.record(
            runId: request.runId,
            type: .toolCallRequested,
            message: tool.displayName,
            metadata: metadata
        )

        if let approvalRequirement = tool.approvalRequirement(for: request.arguments, context: context) {
            let approval = try approvalService.requestApproval(
                runId: request.runId,
                title: approvalRequirement.title,
                summary: approvalRequirement.summary,
                mode: approvalRequirement.mode
            )
            let decision = await approvalService.waitForDecision(requestId: approval.id)
            guard decision == .granted else {
                let output = "Tool request rejected by the user."
                recorder.record(
                    runId: request.runId,
                    type: .toolCallFailed,
                    message: output,
                    metadata: metadata
                )
                return ToolResult(
                    toolId: tool.id,
                    status: .failed,
                    output: output,
                    metadata: metadata.merging([
                        "approvalRequestId": approval.id.uuidString,
                        "approvalStatus": decision.rawValue
                    ]) { _, new in new }
                )
            }
        }

        return try await invokeMCP(request, tool: tool, metadata: metadata)
    }

    private func invokeMCP(
        _ request: ToolExecutionRequest,
        tool: any ToolProtocol,
        metadata: [String: String]
    ) async throws -> ToolResult {
        recorder.record(runId: request.runId, type: .toolCallStarted, message: tool.displayName, metadata: metadata)

        do {
            let result = try await mcpClient.invoke(.init(
                toolId: tool.id,
                arguments: request.arguments,
                projectRootPath: request.projectRootPath
            ))
            recorder.record(
                runId: request.runId,
                type: .toolCallFinished,
                message: tool.displayName,
                metadata: metadata.merging(["status": result.status.rawValue]) { _, new in new }
            )
            recorder.record(
                runId: request.runId,
                type: .toolResult,
                message: result.output,
                metadata: result.metadata
            )
            return result
        } catch {
            recorder.record(
                runId: request.runId,
                type: .toolCallFailed,
                message: error.localizedDescription,
                metadata: metadata
            )
            throw error
        }
    }

    private func toolMetadata(for request: ToolExecutionRequest, tool: any ToolProtocol) -> [String: String] {
        [
            "toolExecutionId": request.id.uuidString,
            "toolId": tool.id,
            "permission": tool.permission.rawValue
        ]
    }
}
