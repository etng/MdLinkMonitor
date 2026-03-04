import Foundation

enum MainWindowPanel: CaseIterable {
    case preview
    case calendar
    case settings
    case updates
    case help

    var symbolName: String {
        switch self {
        case .preview: return "doc.text.image"
        case .calendar: return "calendar"
        case .settings: return "slider.horizontal.3"
        case .updates: return "arrow.triangle.2.circlepath"
        case .help: return "questionmark.circle"
        }
    }
}
