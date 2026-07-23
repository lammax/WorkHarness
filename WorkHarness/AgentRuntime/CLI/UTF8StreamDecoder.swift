//
// UTF8StreamDecoder.swift
// WorkHarness
//
// Created by Auto (Codex) on 23.07.2026.
//

import Foundation

struct UTF8StreamDecoder {
    private var pendingData = Data()

    mutating func decode(_ data: Data) -> String {
        pendingData.append(data)
        guard !pendingData.isEmpty else { return "" }

        if let text = String(data: pendingData, encoding: .utf8) {
            pendingData.removeAll(keepingCapacity: true)
            return text
        }

        let maximumIncompleteScalarByteCount = min(3, pendingData.count)
        for suffixByteCount in 1...maximumIncompleteScalarByteCount {
            let prefix = pendingData.dropLast(suffixByteCount)
            guard let text = String(data: prefix, encoding: .utf8) else { continue }
            pendingData = Data(pendingData.suffix(suffixByteCount))
            return text
        }

        return ""
    }

    mutating func finish() -> String {
        defer { pendingData.removeAll(keepingCapacity: false) }
        return String(decoding: pendingData, as: UTF8.self)
    }
}
