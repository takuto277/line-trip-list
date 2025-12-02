import Foundation
import Combine
import LineSDK

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
            print("[VM] loginWithLine invoked")
            #if canImport(LineSDK)
            // Bridge the callback-based LoginManager API into async/await
            let loginResult: LoginResult = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<LoginResult, Error>) in
                LoginManager.shared.login(permissions: [.profile]) { result in
                    switch result {
                    case .success(let lr):
                        cont.resume(returning: lr)
                    case .failure(let err):
                        cont.resume(throwing: err)
                    }
                }
            }

            // Extract access token and fetch profile
            let token = loginResult.accessToken.value
            print("[VM] LINE login succeeded, token available")
            try await authService.login(accessToken: token)
            #else
            // Fallback: if LineSDK is not available (e.g., in unit tests), keep the dev-simulated path
            let fakeAccessToken = "dev-token-\(UUID().uuidString)"
            let fakeUser = LineUser(userId: "User-Dev-\(Int.random(in: 1000..<9999))", displayName: "Dev User", pictureUrl: "https://picsum.photos/200", statusMessage: nil)
            authService.login(accessToken: fakeAccessToken, user: fakeUser)
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        authService.logout()
    }
}
