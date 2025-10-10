import SwiftUI

@main
struct ContextBuilderApp: App {
    @StateObject private var viewModel = ContextViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContextListView(viewModel: viewModel)
                    .onAppear { viewModel.refresh() }
            }
        }
    }
}
