//
// ToolPathResolver.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

enum ToolPathResolver {
    static func resolvePath(_ path: String, projectRootPath: String?) throws -> URL {
        guard let projectRootPath, !projectRootPath.isEmpty else {
            throw ToolError.missingProjectRoot
        }

        let rootURL = URL(fileURLWithPath: projectRootPath).standardizedFileURL
        let targetURL: URL

        if path.hasPrefix("/") {
            targetURL = URL(fileURLWithPath: path).standardizedFileURL
        } else {
            targetURL = rootURL.appendingPathComponent(path).standardizedFileURL
        }

        guard targetURL.path == rootURL.path || targetURL.path.hasPrefix(rootURL.path + "/") else {
            throw ToolError.pathEscapesProjectRoot(path)
        }

        return targetURL
    }
}
