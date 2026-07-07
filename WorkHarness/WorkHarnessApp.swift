//
//  WorkHarnessApp.swift
//  WorkHarness
//
//  Created by Максим Ламанский on 7.07.26.
//

import SwiftUI

@main
struct WorkHarnessApp: App {
    @State private var appContainer = AppContainer()

    var body: some Scene {
        WindowGroup {
            ContentView(chatViewModel: appContainer.chatViewModel, navigationViewModel: appContainer.navigationViewModel)
        }
    }
}
