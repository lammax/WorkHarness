//
// ContextMemoryRetrievalPolicy.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation

struct ContextMemoryRetrievalSelection: Equatable {
    var selectedReferences: [MemoryReference]
    var omittedReferenceCount: Int
    var isEnabled: Bool
}

struct ContextMemoryRetrievalPolicy: Equatable {
    var maximumItemCount: Int
    var maximumCharacterCount: Int

    init(
        maximumItemCount: Int = 8,
        maximumCharacterCount: Int = 8_000
    ) {
        self.maximumItemCount = max(0, maximumItemCount)
        self.maximumCharacterCount = max(0, maximumCharacterCount)
    }

    func select(
        from references: [MemoryReference],
        contextPolicy: ContextPolicy,
        memoryPolicy: MemoryPolicy
    ) throws -> ContextMemoryRetrievalSelection {
        try Task.checkCancellation()
        guard contextPolicy.includeMemoryFacts, memoryPolicy.canReadMemory else {
            return ContextMemoryRetrievalSelection(
                selectedReferences: [],
                omittedReferenceCount: references.count,
                isEnabled: false
            )
        }

        let orderedReferences = references.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt > $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        var selectedReferences: [MemoryReference] = []
        var selectedCharacterCount = 0

        for reference in orderedReferences {
            try Task.checkCancellation()
            guard selectedReferences.count < maximumItemCount else { break }
            let characterCount = max(0, reference.contentCharacterCount)
            guard selectedCharacterCount + characterCount <= maximumCharacterCount else { continue }
            selectedReferences.append(reference)
            selectedCharacterCount += characterCount
        }

        return ContextMemoryRetrievalSelection(
            selectedReferences: selectedReferences,
            omittedReferenceCount: max(0, references.count - selectedReferences.count),
            isEnabled: true
        )
    }
}
