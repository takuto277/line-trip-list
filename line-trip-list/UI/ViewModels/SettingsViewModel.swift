import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var displayNameOverrides: [String: String] = [:]

    private let nameStore: DisplayNameStore
    let authService: AuthenticationService

    init(nameStore: DisplayNameStore, authService: AuthenticationService) {
        self.nameStore = nameStore
        self.authService = authService
        self.displayNameOverrides = nameStore.overrides
    }

    func setOverride(_ id: String, name: String) {
        nameStore.setOverride(name, for: id)
        displayNameOverrides = nameStore.overrides
    }

    func removeOverride(_ id: String) {
        nameStore.removeOverride(for: id)
        displayNameOverrides = nameStore.overrides
    }

    var currentUserDisplayName: String? {
        authService.currentUser?.displayName
    }
}
