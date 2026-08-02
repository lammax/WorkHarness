//
// RunArtifactContentService.swift
// WorkHarness
//
// Created by Auto (Codex) on 02.08.2026.
//

import Foundation

@MainActor
protocol RunArtifactContentServiceProtocol: BaseServiceProtocol {
    func content(artifactId: UUID, offset: Int, limit: Int) throws -> RunArtifactContentPage
    func cleanup(olderThan cutoff: Date) throws -> Int
}

extension RunArtifactContentServiceProtocol {
    var service: AppService { .runs }
}

@MainActor
final class RunArtifactContentService: RunArtifactContentServiceProtocol {
    private let artifactStore: RunArtifactStoreProtocol

    init(artifactStore: RunArtifactStoreProtocol) {
        self.artifactStore = artifactStore
    }

    func content(artifactId: UUID, offset: Int, limit: Int) throws -> RunArtifactContentPage {
        try artifactStore.readText(artifactId: artifactId, offset: offset, limit: limit)
    }

    func cleanup(olderThan cutoff: Date) throws -> Int {
        try artifactStore.cleanupArtifacts(olderThan: cutoff)
    }
}
