import Foundation

@MainActor
final class SettingsDraftCoordinator: ObservableObject {
    @Published var hasUnsavedChanges = false

    var saveChanges: (() -> Void)?
    var discardChanges: (() -> Void)?

    func save() {
        saveChanges?()
        hasUnsavedChanges = false
    }

    func discard() {
        discardChanges?()
        hasUnsavedChanges = false
    }
}
