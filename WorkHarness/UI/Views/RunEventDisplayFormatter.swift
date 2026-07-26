//
// RunEventDisplayFormatter.swift
// WorkHarness
//
// Created by Auto (Codex) on 26.07.2026.
//

import Foundation

enum RunEventDisplayFormatter {
    static func title(for event: RunEvent) -> String {
        if event.metadata["executionLoopProgress"] == "true",
           let taskId = event.metadata["taskId"] {
            let detail = event.metadata["assistantName"] ?? event.type.label
            return "\(taskId) · \(detail)"
        }
        if event.type == .providerStreamDelta, event.metadata["source"] == "acp" {
            return "Assistant"
        }
        return event.type.label
    }

    static func message(for event: RunEvent) -> String {
        guard event.type == .toolResult else {
            return event.message
        }

        return toolResult(from: event.message)
    }

    private static func toolResult(from rawMessage: String) -> String {
        guard
            let data = rawMessage.data(using: .utf8),
            let value = try? JSONSerialization.jsonObject(with: data)
        else {
            return rawMessage
        }

        if let object = value as? [String: Any] {
            if let fileResult = fileResult(from: object) {
                return fileResult
            }
            if let shellResult = shellResult(from: object) {
                return shellResult
            }
        }

        let formatted = formattedValue(value)
        return formatted.isEmpty ? rawMessage : formatted
    }

    private static func fileResult(from object: [String: Any]) -> String? {
        guard let content = object["content"] as? String else {
            return nil
        }

        guard let path = nonEmptyString(object["path"]) else {
            return content
        }

        return "File: \(path)\n\n\(content)"
    }

    private static func shellResult(from object: [String: Any]) -> String? {
        guard
            object["standardOutput"] != nil
                || object["standardError"] != nil
                || object["exitCode"] != nil
        else {
            return nil
        }

        let output = nonEmptyString(object["standardOutput"])
        let error = nonEmptyString(object["standardError"])
        let exitCode = object["exitCode"] as? NSNumber
        var sections: [String] = []

        if let output {
            sections.append(output)
        }
        if let error {
            sections.append("Error output:\n\(error)")
        }
        if let exitCode, exitCode.intValue != 0 || sections.isEmpty {
            sections.append("Exit code: \(exitCode.intValue)")
        }

        return sections.joined(separator: "\n\n")
    }

    private static func formattedValue(_ value: Any, indentation: String = "") -> String {
        if let object = value as? [String: Any] {
            return object.keys.sorted().compactMap { key in
                let formatted = formattedValue(object[key] as Any, indentation: indentation + "  ")
                guard !formatted.isEmpty else { return nil }
                return "\(indentation)\(humanized(key)): \(formatted)"
            }
            .joined(separator: "\n")
        }

        if let array = value as? [Any] {
            return array.compactMap { item in
                let formatted = formattedValue(item, indentation: indentation + "  ")
                guard !formatted.isEmpty else { return nil }
                return "\n\(indentation)• \(formatted)"
            }
            .joined()
        }

        if value is NSNull {
            return ""
        }
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }

        return String(describing: value)
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String else {
            return nil
        }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func humanized(_ key: String) -> String {
        var result = ""

        for character in key.replacingOccurrences(of: "_", with: " ") {
            if character.isUppercase, let last = result.last, last != " " {
                result.append(" ")
            }
            result.append(character)
        }

        let normalized = result.lowercased()
        return normalized.prefix(1).uppercased() + normalized.dropFirst()
    }
}
