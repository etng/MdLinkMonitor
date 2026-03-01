import CBMCore
import SwiftUI

@main
struct CBMMenuBarApp: App {
    @StateObject private var viewModel = MenuBarViewModel()

    var body: some Scene {
        MenuBarExtra(viewModel.text(.appTitle), systemImage: "link") {
            MenuBarContentView(model: viewModel)
        }
        .menuBarExtraStyle(.window)

        WindowGroup(id: "preview", for: String.self) { value in
            MarkdownPreviewView(
                filePath: value.wrappedValue ?? viewModel.openTodayFilePath(),
                language: viewModel.settings.language
            )
        }

        WindowGroup(id: "about") {
            AboutView()
        }
    }
}
