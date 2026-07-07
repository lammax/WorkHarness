//
// BasePageProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

protocol BasePageProtocol: Viewable {
    var tag: String { get }
}

extension BasePageProtocol {
    var tag: String { String(describing: Self.self) }
}
