//
// MarkdownExecutionTaskSource.swift
// WorkHarness
//
// Created by Auto (Codex) on 26.07.2026.
//

import Foundation

final class MarkdownExecutionTaskSource: ExecutionTaskSourceProtocol {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func loadTaskPool(at sourceURL: URL) throws -> ExecutionTaskPool {
        let standardizedURL = sourceURL.standardizedFileURL
        guard fileManager.fileExists(atPath: standardizedURL.path),
              let markdown = try? String(contentsOf: standardizedURL, encoding: .utf8) else {
            throw ExecutionTaskSourceError.sourceUnavailable(standardizedURL.path)
        }

        let lines = markdown.components(separatedBy: .newlines)
        guard let repository = inlineCodeValue(after: "- Repository:", in: lines) else {
            throw ExecutionTaskSourceError.missingTargetRepository
        }
        guard let baseBranch = inlineCodeValue(after: "- Base branch:", in: lines) else {
            throw ExecutionTaskSourceError.missingBaseBranch
        }
        guard let buildCommand = inlineCodeValue(after: "- Build command:", in: lines) else {
            throw ExecutionTaskSourceError.missingBuildCommand
        }
        guard let testCommand = inlineCodeValue(after: "- Test command:", in: lines) else {
            throw ExecutionTaskSourceError.missingTestCommand
        }

        let taskStartIndices = lines.indices.filter { lines[$0].hasPrefix("### WHM-") }
        guard !taskStartIndices.isEmpty else {
            throw ExecutionTaskSourceError.noTasks
        }

        let tasks = try taskStartIndices.enumerated().map { position, startIndex in
            let endIndex = position + 1 < taskStartIndices.count
                ? taskStartIndices[position + 1]
                : lines.endIndex
            return try parseTask(Array(lines[startIndex..<endIndex]))
        }

        return ExecutionTaskPool(
            sourcePath: standardizedURL.path,
            targetRepositoryPath: URL(
                fileURLWithPath: repository,
                isDirectory: true
            ).standardizedFileURL.path,
            baseBranch: baseBranch,
            buildCommand: buildCommand,
            testCommand: testCommand,
            tasks: tasks
        )
    }

    private func parseTask(_ lines: [String]) throws -> ExecutionTask {
        guard let heading = lines.first else {
            throw ExecutionTaskSourceError.malformedTask("unknown")
        }
        let headingContents = String(heading.dropFirst("### ".count))
        let headingParts = headingContents.components(separatedBy: " — ")
        guard headingParts.count == 2 else {
            throw ExecutionTaskSourceError.malformedTask(headingContents)
        }

        let id = headingParts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let title = headingParts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawCategory = inlineCodeValue(after: "- Category:", in: lines),
              let category = ExecutionTaskCategory(rawValue: rawCategory.lowercased()) else {
            let rawCategory = inlineCodeValue(after: "- Category:", in: lines) ?? "missing"
            throw ExecutionTaskSourceError.unsupportedCategory(rawCategory)
        }
        guard let goalLine = lines.first(where: { $0.hasPrefix("- Goal:") }) else {
            throw ExecutionTaskSourceError.malformedTask(id)
        }

        let rawDependencies = inlineCodeValue(after: "- Dependencies:", in: lines) ?? "none"
        let dependencies = rawDependencies.lowercased() == "none"
            ? []
            : rawDependencies
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let goal = String(goalLine.dropFirst("- Goal:".count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !title.isEmpty, !goal.isEmpty else {
            throw ExecutionTaskSourceError.malformedTask(id)
        }

        return ExecutionTask(
            id: id,
            title: title,
            category: category,
            dependencies: dependencies,
            goal: goal,
            definition: lines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func inlineCodeValue(after prefix: String, in lines: [String]) -> String? {
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        let value = String(line.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasPrefix("`"), value.hasSuffix("`"), value.count >= 2 else {
            return value.isEmpty ? nil : value
        }
        return String(value.dropFirst().dropLast())
    }
}

