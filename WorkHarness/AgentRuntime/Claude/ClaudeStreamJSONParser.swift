//
// ClaudeStreamJSONParser.swift
// WorkHarness
//
// Created by Auto (Codex) on 23.07.2026.
//

import Foundation

enum ClaudeStreamJSONParserError: LocalizedError, Equatable {
    case invalidJSON(String)
    case invalidEnvelope

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let message):
            "Claude stream-json is invalid: \(message)"
        case .invalidEnvelope:
            "Claude stream-json message is not an object."
        }
    }
}

final class ClaudeStreamJSONParser {
    private(set) var sessionId: String?
    private(set) var didReceiveResult = false

    private var buffer = ""
    private var streamedText = ""
    private var latestAssistantText = ""
    private var emittedToolCallIds: Set<String> = []
    private var didStart = false

    func parse(_ chunk: String) throws -> [AgentEvent] {
        buffer += chunk
        let lines = buffer.components(separatedBy: .newlines)
        buffer = lines.last ?? ""
        return try lines.dropLast().flatMap(parseLine)
    }

    func finish() throws -> [AgentEvent] {
        let remainder = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        buffer = ""
        guard !remainder.isEmpty else { return [] }
        return try parseLine(remainder)
    }

    private func parseLine(_ line: String) throws -> [AgentEvent] {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty else { return [] }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: Data(trimmedLine.utf8))
        } catch {
            throw ClaudeStreamJSONParserError.invalidJSON(error.localizedDescription)
        }
        guard let envelope = object as? [String: Any] else {
            throw ClaudeStreamJSONParserError.invalidEnvelope
        }

        switch envelope["type"] as? String {
        case "system":
            return parseSystem(envelope)
        case "stream_event":
            return parseStreamEvent(envelope)
        case "assistant":
            return parseAssistant(envelope)
        case "result":
            return parseResult(envelope)
        case "user", "rate_limit_event":
            return []
        default:
            return []
        }
    }

    private func parseSystem(_ envelope: [String: Any]) -> [AgentEvent] {
        guard envelope["subtype"] as? String == "init", !didStart else { return [] }
        sessionId = envelope["session_id"] as? String
        didStart = true
        return [.started]
    }

    private func parseStreamEvent(_ envelope: [String: Any]) -> [AgentEvent] {
        guard let event = envelope["event"] as? [String: Any],
              event["type"] as? String == "content_block_delta",
              let delta = event["delta"] as? [String: Any],
              let deltaType = delta["type"] as? String else {
            return []
        }

        switch deltaType {
        case "text_delta":
            guard let text = delta["text"] as? String, !text.isEmpty else { return [] }
            streamedText += text
            return [.textDelta(text)]
        case "thinking_delta":
            guard let thinking = delta["thinking"] as? String, !thinking.isEmpty else { return [] }
            return [.thinking(thinking)]
        default:
            return []
        }
    }

    private func parseAssistant(_ envelope: [String: Any]) -> [AgentEvent] {
        guard let message = envelope["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else {
            return []
        }

        var events: [AgentEvent] = []
        let text = content.compactMap { block -> String? in
            guard block["type"] as? String == "text" else { return nil }
            return block["text"] as? String
        }.joined()
        if !text.isEmpty {
            latestAssistantText = text
        }

        for block in content where block["type"] as? String == "tool_use" {
            let id = block["id"] as? String ?? UUID().uuidString
            guard emittedToolCallIds.insert(id).inserted else { continue }
            let name = block["name"] as? String ?? "tool"
            events.append(.toolCallRequested(name: name, input: jsonString(block["input"])))
        }

        return events
    }

    private func parseResult(_ envelope: [String: Any]) -> [AgentEvent] {
        didReceiveResult = true
        sessionId = envelope["session_id"] as? String ?? sessionId
        if envelope["is_error"] as? Bool == true {
            let message = envelope["result"] as? String
                ?? envelope["subtype"] as? String
                ?? "Claude Code failed."
            return [.failed(message)]
        }

        let message = nonEmpty(envelope["result"] as? String)
            ?? nonEmpty(latestAssistantText)
            ?? streamedText
        let usage = tokenUsage(from: envelope)
        return [
            .tokenUsage(usage),
            .messageCompleted(message),
            .finished(AgentResponse(message: message, tokenUsage: usage, artifacts: []))
        ]
    }

    private func tokenUsage(from envelope: [String: Any]) -> TokenUsage {
        let usage = envelope["usage"] as? [String: Any]
        return TokenUsage(
            inputTokens: usage?["input_tokens"] as? Int ?? 0,
            outputTokens: usage?["output_tokens"] as? Int ?? 0,
            totalCostUSD: decimal(envelope["total_cost_usd"])
        )
    }

    private func decimal(_ value: Any?) -> Decimal {
        if let number = value as? NSNumber {
            return number.decimalValue
        }
        if let text = value as? String {
            return Decimal(string: text) ?? 0
        }
        return 0
    }

    private func jsonString(_ value: Any?) -> String {
        guard let value, JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
