//
//  ContentView.swift
//  WorkHarness
//
//  Created by Максим Ламанский on 7.07.26.
//

import SwiftUI

struct ContentView: View {
    @Bindable var chatViewModel: ChatViewModel
    @Bindable var navigationViewModel: AppNavigationViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $navigationViewModel.selectedSection, runs: chatViewModel.runs) { run in
                navigationViewModel.selectRun(run, chatViewModel: chatViewModel)
            }
            .navigationSplitViewColumnWidth(min: AppDesign.Window.sidebarMinWidth, ideal: AppDesign.Window.sidebarIdealWidth)
        } detail: {
            detailView
        }
        .frame(minWidth: AppDesign.Window.minWidth, minHeight: AppDesign.Window.minHeight)
    }

    @ViewBuilder
    private var detailView: some View {
        switch navigationViewModel.selectedSection {
        case .chat:
            ChatView(viewModel: chatViewModel)
        case .runs:
            RunsView(runs: chatViewModel.runs) { run in
                navigationViewModel.selectRun(run, chatViewModel: chatViewModel)
            }
        case .agents, .tools, .memory, .stats, .settings:
            PlaceholderSectionView(section: navigationViewModel.selectedSection)
        }
    }
}

#Preview {
    let appContainer = AppContainer()
    ContentView(chatViewModel: appContainer.chatViewModel, navigationViewModel: appContainer.navigationViewModel)
}
