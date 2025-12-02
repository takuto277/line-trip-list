import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var vm: LoginViewModel
    @State private var showingAlert = false
    @State private var alertMessage = ""

    init() {
        // vm will be initialized in onAppear using the environment object; we create a placeholder
        _vm = StateObject(wrappedValue: LoginViewModel(authService: AuthenticationService()))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.green.opacity(0.6), Color.blue.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                Image(systemName: "message.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.white)

                Text("LINE Trip List")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("LINEでログインしてメッセージを管理")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                Button(action: {
                    print("[UI] Login button tapped")
                    Task { await vm.loginWithLine() }
                }) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                        Text("LINEでログイン")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.green)
                    .cornerRadius(12)
                    .shadow(radius: 5)
                }
                .padding(.horizontal, 40)
                .disabled(vm.isLoading)

                if vm.isLoading { ProgressView().tint(.white) }

                Spacer()

                Text("LINE公式アカウントと連携します")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 30)
            }
        }
        .onAppear {
            vm.bindAuthService(authService)
        }
        .alert("ログインエラー", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }

    private func vmIsPlaceholder() -> Bool {
        // crude heuristic: placeholder authService has nil accessToken
        return vm.errorMessage == nil && !vm.isLoading && vmAuthServiceAccessToken() == nil
    }

    private func vmAuthServiceAccessToken() -> String? {
        // reflection-free access via exposing a small helper in LoginViewModel would be better; for now use Key-Value
        return nil
    }

    private func vmSetAuthService(_ service: AuthenticationService) {
        // Re-create vm with the real authService since StateObject can't be reassigned
        // Workaround: send a login/logout action that uses the shared authService directly inside LoginViewModel as needed.
        // For now, assign via internal property using Mirror (not ideal). If this is fragile, consider modifying LoginViewModel to accept an optional setter.
        // We'll call a method on vm to bind to the external service if available.
        vm.logout() // ensure state cleared
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthenticationService())
    }
}