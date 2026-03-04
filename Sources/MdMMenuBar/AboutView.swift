import MdMCore
import MarkdownUI
import SwiftUI
import AppKit

struct AboutView: View {
    let language: AppLanguage
    private let repositoryURL = URL(string: "https://github.com/etng/MdLinkMonitor")!

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppLocalizer.text(.about, language: language))
                .font(.title2.weight(.semibold))

            Text("\(AppLocalizer.text(.currentVersion, language: language)): \(AppVersion.displayVersion)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Link("GitHub: etng/MdLinkMonitor", destination: repositoryURL)
                .font(.subheadline)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Markdown(helpMarkdown)
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    donationSection
                }
            }
        }
        .padding(20)
        .frame(minWidth: 540, minHeight: 520)
    }

    @ViewBuilder
    private var donationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(local("支持作者", "Support the Author"))
                .font(.headline)

            Text(donationMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 14) {
                donationImage(
                    name: "wechat_donate_xugu",
                    ext: "png",
                    title: "WeChat"
                )

                donationImage(
                    name: "alipay_donate_xugu",
                    ext: "jpg",
                    title: "Alipay"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func donationImage(name: String, ext: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let image = loadDonationImage(name: name, ext: ext) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 160)
                    .overlay(
                        Text(local("图片未找到", "Image not found"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadDonationImage(name: String, ext: String) -> NSImage? {
        let fileManager = FileManager.default
        var bundles: [Bundle] = [Bundle.main]

        if let resources = Bundle.main.resourceURL,
           let entries = try? fileManager.contentsOfDirectory(
            at: resources,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
           ) {
            for entry in entries where entry.pathExtension == "bundle" {
                if let bundle = Bundle(url: entry) {
                    bundles.append(bundle)
                }
            }
        }

        for bundle in bundles {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "donations")
                ?? bundle.url(forResource: name, withExtension: ext),
               fileManager.fileExists(atPath: url.path(percentEncoded: false)),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }

        let fallbackURLs: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent("donations/\(name).\(ext)"),
            Bundle.main.resourceURL?.appendingPathComponent("\(name).\(ext)")
        ]

        for url in fallbackURLs.compactMap({ $0 }) {
            if fileManager.fileExists(atPath: url.path(percentEncoded: false)),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }

        return nil
    }

    private var donationMessage: String {
        switch language {
        case .zhHans:
            return "本代码虽然用Codex生成但是仍然费了我不少心血，作为免费软件发布，希望你能喜欢。如果你能酌情捐款补贴我购买token的话，不胜感激!"
        case .en:
            return "This project was generated with Codex but still took significant effort. It is released for free and I hope you enjoy it. If you'd like to donate to help cover my token cost, I'd really appreciate it."
        }
    }

    private var helpMarkdown: String {
        switch language {
        case .zhHans:
            return """
            ## 使用说明

            1. 在菜单栏中点击 **预览 > 今天** 或 **预览 > 日历** 打开主窗口。
            2. 当复制内容中包含 Markdown 链接（例如 `[label](link)`）时，程序会自动检测并写入当日 `links_YYYYMMDD.md`。
            3. 若链接命中已配置的仓库域名与路径格式，程序会按设置中的克隆命令模板执行（默认：`git clone {repo}.git`）。
            4. 日历面板中，带书签图标的日期表示当天有记录；双击日期可直接打开该天预览。
            5. 设置面板可调整输出目录、仓库域名、监控开关、通知和字体等偏好。
            6. 日志写入与 markdown 同目录，按天保存为 `logs_YYYYMMDD.log`，用于排查问题。
            7. 可在 **设置 > 系统 > 安装 mdm 命令** 安装命令行工具，必要时会请求管理员授权。
            8. `mdm` 常用命令：
               - `mdm today --path`：输出今日 markdown 路径
               - `mdm today --print`：输出今日 markdown 内容
               - `mdm status`：输出当前配置快照
               - `mdm help`：查看帮助
            9. 项目使用 MIT 许可证，第三方组件鸣谢请见仓库文档。
            """
        case .en:
            return """
            ## Usage

            1. Open the main window from **Preview > Today** or **Preview > Calendar**.
            2. When copied text contains markdown links like `[label](link)`, the app parses and appends them to today's `links_YYYYMMDD.md`.
            3. If a link matches configured repository domains and path rules, the app runs your configured clone command template (default: `git clone {repo}.git`).
            4. In the calendar panel, bookmarked days indicate available records. Double-click a day to jump to preview.
            5. Use Settings to configure output directory, repository domains, monitoring, notifications, and font preferences.
            6. Logs are saved next to markdown files as `logs_YYYYMMDD.log` for diagnostics.
            7. Install the CLI from **Settings > System > Install mdm Command** (macOS may request administrator authorization).
            8. Common `mdm` commands:
               - `mdm today --path`: print today's markdown path
               - `mdm today --print`: print today's markdown content
               - `mdm status`: print current settings snapshot
               - `mdm help`: show command help
            9. The project is MIT licensed. See repository docs for third-party acknowledgements.
            """
        }
    }

    private func local(_ zhHans: String, _ en: String) -> String {
        language == .zhHans ? zhHans : en
    }
}
