//
// CursorACPModels.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

struct CursorACPModelOption: Identifiable, Equatable, CaseIterable {
    let id: String
    let title: String

    static let allCases: [CursorACPModelOption] = [
        .init(id: "composer-2.5[fast=true]", title: "Composer 2.5 · Fast"),
        .init(id: "claude-opus-4-8[thinking=true,context=300k,effort=high,fast=false]", title: "Opus 4.8 · High"),
        .init(id: "gpt-5.6-sol[context=272k,reasoning=medium,fast=false]", title: "GPT-5.6 Sol · Medium"),
        .init(id: "gpt-5.5[context=272k,reasoning=medium,fast=false]", title: "GPT-5.5 · Medium"),
        .init(id: "claude-fable-5[thinking=true,context=300k,effort=high]", title: "Fable 5 · High"),
        .init(id: "claude-sonnet-5[thinking=true,context=300k,effort=high,fast=false]", title: "Sonnet 5 · High"),
        .init(id: "gpt-5.6-terra[context=272k,reasoning=medium,fast=false]", title: "GPT-5.6 Terra · Medium"),
        .init(id: "claude-sonnet-4-6[thinking=true,context=200k,effort=medium,fast=false]", title: "Sonnet 4.6 · Medium"),
        .init(id: "gpt-5.3-codex[reasoning=medium,fast=false]", title: "Codex 5.3 · Medium")
    ]

    static let defaultModel = allCases[0]
}
