import CBMCore
import MarkdownUI
import SwiftUI

struct MarkdownPreviewView: View {
    let initialFilePath: String
    let outputDirectoryPath: String
    let language: AppLanguage

    @State private var files: [URL] = []
    @State private var selectedFilePath: String?
    @State private var content = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedFilePath) {
                ForEach(files, id: \.path) { file in
                    Text(file.lastPathComponent)
                        .tag(file.path(percentEncoded: false))
                }
            }
            .navigationTitle(sidebarTitle)
        } detail: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(selectedFilePath ?? initialFilePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button(AppLocalizer.text(.reload, language: language)) {
                        reloadFilesAndContent()
                    }
                }

                Divider()

                ScrollView {
                    if content.isEmpty {
                        Text(emptyContentHint)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    } else {
                        Markdown(content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(16)
        }
        .frame(minWidth: 920, minHeight: 620)
        .onAppear(perform: reloadFilesAndContent)
        .onChange(of: selectedFilePath) { _ in
            loadSelectedContent()
        }
    }

    private var sidebarTitle: String {
        language == .zhHans ? "历史文件" : "History"
    }

    private var emptyContentHint: String {
        language == .zhHans ? "该文件暂无内容" : "No content in this file"
    }

    private func reloadFilesAndContent() {
        let store = DailyMarkdownStore(baseDirectoryPath: outputDirectoryPath)
        files = (try? store.listRecentDailyFiles(limit: nil)) ?? []

        if let selected = selectedFilePath, files.contains(where: { $0.path(percentEncoded: false) == selected }) {
            loadSelectedContent()
            return
        }

        if files.contains(where: { $0.path(percentEncoded: false) == initialFilePath }) {
            selectedFilePath = initialFilePath
        } else {
            selectedFilePath = files.first?.path(percentEncoded: false) ?? initialFilePath
        }

        loadSelectedContent()
    }

    private func loadSelectedContent() {
        let current = selectedFilePath ?? initialFilePath
        let url = URL(filePath: current)
        content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}
