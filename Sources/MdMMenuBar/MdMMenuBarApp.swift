import AppKit
import MdMCore
import SwiftUI

@main
struct MdMonitorApp: App {
    @StateObject private var viewModel = MenuBarViewModel()

    init() {
        NSApplication.shared.applicationIconImage = AppIconFactory.dockIcon()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: viewModel)
        } label: {
            Image(nsImage: AppIconFactory.menuBarIcon(feedback: viewModel.recentCaptureFeedbackKind))
        }
        .menuBarExtraStyle(.window)
    }
}
