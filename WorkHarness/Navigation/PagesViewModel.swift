//
// PagesViewModel.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
class PagesViewModel {
    private(set) var pages: [any BasePageProtocol] = []
    var alpha = 1.0
    var isHidePreviousPage = true

    let transitionDuration = 0.2

    private var isAbandoned = false

    func close() {
        isAbandoned = true
        pages = []
    }

    func setPages(_ pages: [any BasePageProtocol]) {
        guard !isAbandoned else { return }
        self.pages = pages
    }

    func pushHard(page: any BasePageProtocol) {
        guard !isAbandoned else { return }
        pages.append(page)
        alpha = 1
        isHidePreviousPage = true
    }

    func push(page: any BasePageProtocol) {
        guard !isAbandoned else { return }
        alpha = 0
        isHidePreviousPage = false
        pages.append(page)

        withAnimation(.linear(duration: transitionDuration)) {
            alpha = 1
        }

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.transitionDuration ?? 0.2))
            await MainActor.run {
                self?.isHidePreviousPage = true
            }
        }
    }

    func sowHard(page: any BasePageProtocol) {
        guard !isAbandoned else { return }
        pages = [page]
        alpha = 1
        isHidePreviousPage = true
    }

    func sow(page: any BasePageProtocol) {
        guard !isAbandoned else { return }
        alpha = 0
        isHidePreviousPage = false
        pages.append(page)

        withAnimation(.linear(duration: transitionDuration)) {
            alpha = 1
        }

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.transitionDuration ?? 0.2))
            await MainActor.run {
                guard let self, !self.isAbandoned else { return }
                self.pages = [page]
                self.isHidePreviousPage = true
            }
        }
    }

    func popPage() {
        popPage(isAnimated: true)
    }

    func popPage(isAnimated: Bool, completion: (() -> Void)? = nil) {
        guard !isAbandoned else { return }

        if pages.count <= 1 {
            onEmptyPages()
            completion?()
            return
        }

        isHidePreviousPage = false
        if isAnimated {
            withAnimation(.linear(duration: transitionDuration)) {
                alpha = 0
            }
        }

        Task { [weak self] in
            if isAnimated {
                try? await Task.sleep(for: .seconds(self?.transitionDuration ?? 0.2))
            }
            await MainActor.run {
                guard let self, !self.isAbandoned else { return }
                _ = self.pages.popLast()
                self.alpha = 1
                self.isHidePreviousPage = true
                completion?()
            }
        }
    }

    func onEmptyPages() {}
}
