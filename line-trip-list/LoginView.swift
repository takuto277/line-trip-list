import SwiftUI
import LineSDK

struct LoginView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                gradient: Gradient(colors: [Color.green.opacity(0.6), Color.blue.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // アプリアイコン
                Image(systemName: "message.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.white)
                
                // アプリタイトル
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
                
                // LINEログインボタン
                Button(action: {
                    performLineLogin()
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
                .disabled(isLoading)
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                
                Spacer()
                
                // 注意書き
                Text("LINE公式アカウントと連携します")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 30)
            }
        }
        .alert("ログインエラー", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func performLineLogin() {
        isLoading = true
        
        // LINE SDK Login
        LoginManager.shared.login(permissions: [.profile], in: nil) { result in
            isLoading = false
            
            switch result {
            case .success(let loginResult):
                print("✅ LINE Login Success")
                print("Access Token: \(loginResult.accessToken.value)")
                
                // Get user profile
                API.getProfile { profileResult in
                    switch profileResult {
                    case .success(let profile):
                        print("User ID: \(profile.userID)")
                        print("Display Name: \(profile.displayName)")
                        
                        let user = LineUser(
                            userId: profile.userID,
                            displayName: profile.displayName,
                            pictureUrl: profile.pictureURL?.absoluteString,
                            statusMessage: profile.statusMessage
                        )
                        authService.login(accessToken: loginResult.accessToken.value, user: user)
                        
                    case .failure(let error):
                        alertMessage = "プロフィール取得エラー: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
                
            case .failure(let error):
                alertMessage = "LINEログインエラー: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationService())
}