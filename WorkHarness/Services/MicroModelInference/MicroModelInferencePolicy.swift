//
// MicroModelInferencePolicy.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation

enum MicroModelOutputValidationError: LocalizedError, Equatable {
    case invalidJSON
    case invalidSchema
    case invalidCategory
    case invalidConfidence

    var errorDescription: String? {
        switch self {
        case .invalidJSON: "The model response is not valid JSON."
        case .invalidSchema: "The model response does not match the required schema."
        case .invalidCategory: "The model response contains an unsupported category."
        case .invalidConfidence: "The model confidence must be between 0 and 1."
        }
    }
}

struct MicroModelOutputValidator {
    func validate(_ response: String) throws -> MicroModelClassification {
        guard let data = response.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            throw MicroModelOutputValidationError.invalidJSON
        }
        guard Set(dictionary.keys) == ["category", "confidence", "status"],
              let categoryValue = dictionary["category"] as? String,
              let statusValue = dictionary["status"] as? String,
              let confidenceNumber = dictionary["confidence"] as? NSNumber,
              CFGetTypeID(confidenceNumber) != CFBooleanGetTypeID() else {
            throw MicroModelOutputValidationError.invalidSchema
        }
        let confidence = confidenceNumber.doubleValue
        guard let category = TaskIntentCategory(rawValue: categoryValue) else {
            throw MicroModelOutputValidationError.invalidCategory
        }
        guard confidence.isFinite, (0 ... 1).contains(confidence) else {
            throw MicroModelOutputValidationError.invalidConfidence
        }
        guard let status = MicroModelConfidenceStatus(rawValue: statusValue) else {
            throw MicroModelOutputValidationError.invalidSchema
        }
        return MicroModelClassification(
            category: category,
            confidence: confidence,
            status: status
        )
    }
}

struct MicroModelFallbackPolicy {
    var confidenceThreshold: Double = 0.8

    func reason(
        classification: MicroModelClassification?,
        validationError: MicroModelOutputValidationError?
    ) -> MicroModelFallbackReason? {
        if let validationError {
            switch validationError {
            case .invalidCategory: return .invalidCategory
            case .invalidConfidence: return .invalidConfidence
            case .invalidJSON, .invalidSchema: return .invalidFormat
            }
        }
        guard let classification else { return .invalidFormat }
        guard classification.status == .ok else { return .statusUnsure }
        guard classification.confidence >= confidenceThreshold else { return .lowConfidence }
        return nil
    }
}
