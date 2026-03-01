import CBMCore
import SwiftUI

@main
struct CBMMenuBarApp: App {
    var body: some Scene {
        MenuBarExtra("CBM", systemImage: "link") {
            Text("CBM \(CBMCoreVersion.value)")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
