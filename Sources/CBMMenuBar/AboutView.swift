import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CBM")
                .font(.title2)
                .bold()
            Text("Clipboard Repo Monitor")
            Text("Swift Menu Bar app for collecting GitHub repos from markdown links.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 180)
    }
}
