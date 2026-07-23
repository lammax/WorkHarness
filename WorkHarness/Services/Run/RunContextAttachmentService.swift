//
// RunContextAttachmentService.swift
// WorkHarness
//
// Created by Auto (Codex) on 23.07.2026.
//

import Foundation

@MainActor
protocol RunContextAttachmentServiceProtocol: BaseServiceProtocol {
    func loadAttachment(from url: URL) throws -> RunContextAttachment
}

extension RunContextAttachmentServiceProtocol {
    var service: AppService { .runs }
}

@MainActor
final class RunContextAttachmentService: RunContextAttachmentServiceProtocol {
    static let maximumByteCount = 256 * 1_024

    func loadAttachment(from url: URL) throws -> RunContextAttachment {
        let didAccessSecurityScopedResource = url.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScopedResource {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let resourceValues: URLResourceValues
        do {
            resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        } catch {
            throw RunContextAttachmentError.unreadable
        }

        guard resourceValues.isRegularFile == true else {
            throw RunContextAttachmentError.notAFile
        }

        if let fileSize = resourceValues.fileSize, fileSize > Self.maximumByteCount {
            throw RunContextAttachmentError.tooLarge(maximumByteCount: Self.maximumByteCount)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw RunContextAttachmentError.unreadable
        }

        guard data.count <= Self.maximumByteCount else {
            throw RunContextAttachmentError.tooLarge(maximumByteCount: Self.maximumByteCount)
        }
        guard let content = String(data: data, encoding: .utf8), !content.contains("\0") else {
            throw RunContextAttachmentError.unsupportedEncoding
        }

        return RunContextAttachment(
            name: url.lastPathComponent,
            content: content,
            byteCount: data.count
        )
    }
}

enum RunContextAttachmentError: LocalizedError, Equatable {
    case notAFile
    case unreadable
    case tooLarge(maximumByteCount: Int)
    case unsupportedEncoding

    var errorDescription: String? {
        switch self {
        case .notAFile:
            "Choose a file, not a folder."
        case .unreadable:
            "WorkHarness could not read this file."
        case .tooLarge(let maximumByteCount):
            "The file is too large. Maximum size is \(maximumByteCount / 1_024) KB."
        case .unsupportedEncoding:
            "Only UTF-8 text files can be attached."
        }
    }
}
