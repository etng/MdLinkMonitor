import CBMCore
import SwiftUI

struct MarkdownPreviewView: View {
    let filePath: String
    let language: AppLanguage

    @State private var content = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(filePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button(AppLocalizer.text(.reload, language: language)) {
                    loadContent()
                }
            }

            Divider()

            ScrollView {
                if let attributed = try? AttributedString(markdown: content) {
                    Text(attributed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 680, minHeight: 520)
        .onAppear(perform: loadContent)
    }

    private func loadContent() {
        let url = URL(filePath: filePath)
        content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}
