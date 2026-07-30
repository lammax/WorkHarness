//
// AgentOutputContract.swift
// WorkHarness
//
// Created by Auto (Codex) on 30.07.2026.
//

import Foundation

struct AgentOutputContract: Codable, Equatable {
    var requiredKeys: [String]
    var allowedValues: [String: [String]]
    var requiresExactKeys: Bool

    init(
        requiredKeys: [String],
        allowedValues: [String: [String]] = [:],
        requiresExactKeys: Bool = true
    ) {
        self.requiredKeys = requiredKeys
        self.allowedValues = allowedValues
        self.requiresExactKeys = requiresExactKeys
    }

    var promptInstructions: String {
        var lines = [
            "Structured output contract (mandatory):",
            "- Return exactly one compact JSON object without Markdown fences or surrounding text.",
            "- Use non-empty string values only.",
            "- Required keys: \(requiredKeys.joined(separator: ", "))."
        ]
        if requiresExactKeys {
            lines.append("- Do not add any other keys.")
        }
        lines.append("- Allowed values:")
        for key in requiredKeys {
            if let values = allowedValues[key], !values.isEmpty {
                lines.append("  - \(key): \(values.joined(separator: " | "))")
            } else {
                lines.append("  - \(key): any non-empty string")
            }
        }
        return lines.joined(separator: "\n")
    }
}

struct AgentOutputValidator {
    func validate(_ output: String, against contract: AgentOutputContract) throws {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmedOutput.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data),
              let object = value as? [String: Any] else {
            throw AgentOutputValidationError.invalidJSONObject
        }

        let actualKeys = Set(object.keys)
        let requiredKeys = Set(contract.requiredKeys)
        let missingKeys = requiredKeys.subtracting(actualKeys).sorted()
        guard missingKeys.isEmpty else {
            throw AgentOutputValidationError.missingKeys(missingKeys)
        }

        if contract.requiresExactKeys {
            let unexpectedKeys = actualKeys.subtracting(requiredKeys).sorted()
            guard unexpectedKeys.isEmpty else {
                throw AgentOutputValidationError.unexpectedKeys(unexpectedKeys)
            }
        }

        for key in contract.requiredKeys {
            guard let stringValue = object[key] as? String,
                  !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AgentOutputValidationError.nonStringOrEmptyValue(key: key)
            }

            guard let allowedValues = contract.allowedValues[key] else {
                continue
            }
            guard allowedValues.contains(stringValue) else {
                throw AgentOutputValidationError.disallowedValue(
                    key: key,
                    value: stringValue,
                    allowedValues: allowedValues
                )
            }
        }
    }
}

enum AgentOutputValidationError: LocalizedError, Equatable {
    case invalidJSONObject
    case missingKeys([String])
    case unexpectedKeys([String])
    case nonStringOrEmptyValue(key: String)
    case disallowedValue(key: String, value: String, allowedValues: [String])

    var errorDescription: String? {
        switch self {
        case .invalidJSONObject:
            "Agent output must be one JSON object without Markdown fences or surrounding text."
        case .missingKeys(let keys):
            "Agent output is missing required keys: \(keys.joined(separator: ", "))."
        case .unexpectedKeys(let keys):
            "Agent output contains unexpected keys: \(keys.joined(separator: ", "))."
        case .nonStringOrEmptyValue(let key):
            "Agent output key '\(key)' must contain a non-empty string."
        case .disallowedValue(let key, let value, let allowedValues):
            "Agent output key '\(key)' has unsupported value '\(value)'. Allowed values: \(allowedValues.joined(separator: ", "))."
        }
    }
}
