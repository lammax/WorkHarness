//
// MainShellPageView.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import SwiftUI

extension MainScreen {
    struct MainShellPageView: View {
        typealias Design = MainShellPageDesign

        @Bindable var screenModel: MainScreenViewModel

        var body: some View {
            NavigationSplitView {
                MainSidebarView(screenModel: screenModel)
                    .navigationSplitViewColumnWidth(
                        min: Design.Sidebar.minWidth,
                        ideal: Design.Sidebar.idealWidth
                    )
            } detail: {
                if let detailPage = screenModel.detailPage {
                    detailPage.content
                } else {
                    EmptyView()
                }
            }
            .frame(
                minWidth: Design.Window.minWidth,
                minHeight: Design.Window.minHeight
            )
        }
    }
}
