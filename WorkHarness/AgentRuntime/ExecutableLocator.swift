//
// ExecutableLocator.swift
// WorkHarness
//
// Created by Auto (Codex) on 23.07.2026.
//

import Foundation

enum AgentExecutableLocator {
    static func find(
        named name: String,
        searchPath: String? = ProcessInfo.processInfo.environment["PATH"],
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) -> URL? {
        let pathCandidates = searchPath?
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).appendingPathComponent(name) } ?? []
        let fallbackCandidates = [
            homeDirectoryURL.appendingPathComponent(".local/bin/\(name)"),
            URL(fileURLWithPath: "/opt/homebrew/bin/\(name)"),
            URL(fileURLWithPath: "/usr/local/bin/\(name)")
        ]
        let candidates = pathCandidates + fallbackCandidates

        return candidates.first(where: {
            fileManager.isExecutableFile(atPath: $0.path)
        }) ?? candidates.first(where: {
            fileManager.fileExists(atPath: $0.path)
        })
    }
}
