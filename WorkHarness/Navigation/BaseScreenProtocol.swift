//
// BaseScreenProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

protocol BaseScreenProtocol: Viewable {
    var id: AppScreen { get }
    var pagesModel: PagesViewModel { get }

    func onShown()
    func onClosed()
}

extension BaseScreenProtocol {
    var content: AnyView { AnyView(PagesControlView(viewModel: pagesModel)) }

    func onShown() {}
    func onClosed() {
        pagesModel.close()
    }
}
