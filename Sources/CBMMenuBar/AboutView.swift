import CBMCore
import MarkdownUI
import SwiftUI

struct AboutView: View {
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppLocalizer.text(.about, language: language))
                .font(.title2.weight(.semibold))

            Text("\(AppLocalizer.text(.currentVersion, language: language)): \(AppVersion.displayVersion)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            ScrollView {
                Markdown(helpMarkdown)
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(minWidth: 540, minHeight: 520)
    }

    private var helpMarkdown: String {
        switch language {
        case .zhHans:
            return """
            ## 使用说明

            1. 在菜单栏中点击 **预览 > 今天** 或 **预览 > 日历** 打开主窗口。
            2. 当复制内容中包含 Markdown 链接（例如 `[label](link)`）时，程序会自动检测并写入当日 `links_YYYYMMDD.md`。
            3. 若链接命中已配置的仓库域名与路径格式，程序会按设置中的克隆命令模板执行（默认：`git c1 {repo}.git`）。
            4. 日历面板中，带书签图标的日期表示当天有记录；双击日期可直接打开该天预览。
            5. 设置面板可调整输出目录、仓库域名、监控开关、通知和字体等偏好。
            6. 日志写入与 markdown 同目录，按天保存为 `logs_YYYYMMDD.log`，用于排查问题。

            ## 版本与发布

            - 当前版本遵循 **SemVer**：`主版本.次版本.修订号`。
            - 发布时建议以同版本号打 Git Tag（例如 `v0.2.0`）。
            """
        case .en:
            return """
            ## Usage

            1. Open the main window from **Preview > Today** or **Preview > Calendar**.
            2. When copied text contains markdown links like `[label](link)`, the app parses and appends them to today's `links_YYYYMMDD.md`.
            3. If a link matches configured repository domains and path rules, the app runs your configured clone command template (default: `git c1 {repo}.git`).
            4. In the calendar panel, bookmarked days indicate available records. Double-click a day to jump to preview.
            5. Use Settings to configure output directory, repository domains, monitoring, notifications, and font preferences.
            6. Logs are saved next to markdown files as `logs_YYYYMMDD.log` for diagnostics.

            ## Versioning

            - The app follows **SemVer**: `MAJOR.MINOR.PATCH`.
            - Use the same version in your Git tag, for example `v0.2.0`.
            """
        }
    }
}
