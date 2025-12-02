import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // Make authService a var so we can bind the shared environment instance at runtime
    var authService: AuthenticationService

    init(authService: AuthenticationService) {
        self.authService = authService
    }

    // bind a different authService instance if necessary (used by LoginView onAppear)
    func bindAuthService(_ service: AuthenticationService) {
        // Rebind to the provided AuthenticationService so login actions use the shared instance.
        self.authService = service
    }

    func loginWithLine() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // high level: invoke the service's login flow. Implementation may vary.
            // If AuthenticationService exposes an async login(accessToken:) or similar,
            // call it here. For now we just toggle isLoading and rely on external callback.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        authService.logout()
    }
}
