import CBMCore
import SwiftUI

struct AboutView: View {
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MdMonitor")
                .font(.title2)
                .bold()
            Text(AppLocalizer.text(.aboutHeadline, language: language))
            Text(AppLocalizer.text(.aboutDescription, language: language))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 180)
    }
}
