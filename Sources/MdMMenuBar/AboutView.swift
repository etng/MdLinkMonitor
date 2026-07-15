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

                    feedbackLegendSection

                    Divider()

                    donationSection
                }
            }
        }
        .padding(20)
        .frame(minWidth: 540, minHeight: 520)
    }

    @ViewBuilder
    private var feedbackLegendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(local("捕获反馈颜色", "Capture Feedback Colors"))
                .font(.headline)

            Text(
                local(
                    "当菜单栏图标识别到可处理内容后，会短暂变色。看一眼颜色，就能知道这次是触发克隆、仅写入、重复跳过、被阻止还是处理失败。",
                    "After the menu bar icon recognizes processable content, it briefly changes color. A quick glance tells you whether the app triggered a clone, only saved content, skipped a duplicate, blocked the action, or hit a failure."
                )
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                feedbackLegendRow(
                    .cloned,
                    zhHans: "绿色：识别为仓库，并已触发克隆",
                    en: "Green: recognized as a repository and clone was triggered"
                )
                feedbackLegendRow(
                    .captured,
                    zhHans: "蓝色：识别并已写入或保存，但这次不需要克隆",
                    en: "Blue: recognized and saved, but no clone was needed"
                )
                feedbackLegendRow(
                    .duplicate,
                    zhHans: "橙色：识别到了，但因当天重复或附件已存在而跳过",
                    en: "Orange: recognized, but skipped because it was a duplicate or the attachment already existed"
                )
                feedbackLegendRow(
                    .blocked,
                    zhHans: "灰褐色：识别到了，但被规则阻止，例如附件已在黑名单中",
                    en: "Taupe: recognized, but blocked by a rule such as the attachment blacklist"
                )
                feedbackLegendRow(
                    .failed,
                    zhHans: "红色：识别到了，但后续处理失败，请查看当日日志",
                    en: "Red: recognized, but a follow-up action failed. Check today's log for details"
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func feedbackLegendRow(_ kind: CaptureFeedbackKind, zhHans: String, en: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color(nsColor: AppIconFactory.menuBarFeedbackColor(for: kind) ?? .secondaryLabelColor))
                .frame(width: 10, height: 10)
                .padding(.top, 4)

            Text(local(zhHans, en))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
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
        let commandName = AppRuntimeIdentity.currentCommandName
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
            7. 菜单栏图标在识别到可处理内容后会短暂变色；具体颜色含义见下方“捕获反馈颜色”。
            8. 可在 **设置 > 系统 > 安装 \(commandName) 命令** 安装命令行工具，必要时会请求管理员授权。
            9. `\(commandName)` 常用命令：
               - `\(commandName) today --path`：输出今日 markdown 路径
               - `\(commandName) today --print`：输出今日 markdown 内容
               - `\(commandName) status`：输出当前配置快照
               - `\(commandName) help`：查看帮助
            10. 项目使用 MIT 许可证，第三方组件鸣谢请见仓库文档。
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
            7. After the app recognizes processable content, the menu bar icon briefly changes color. See the feedback legend below for the meaning of each color.
            8. Install the CLI from **Settings > System > Install \(commandName) Command** (macOS may request administrator authorization).
            9. Common `\(commandName)` commands:
               - `\(commandName) today --path`: print today's markdown path
               - `\(commandName) today --print`: print today's markdown content
               - `\(commandName) status`: print current settings snapshot
               - `\(commandName) help`: show command help
            10. The project is MIT licensed. See repository docs for third-party acknowledgements.
            """
        }
    }

    private func local(_ zhHans: String, _ en: String) -> String {
        language == .zhHans ? zhHans : en
    }
}
