import Foundation
import Combine

// LINE Login用のモデル
struct LineUser: Codable {
    let userId: String
    let displayName: String
    let pictureUrl: String?
    let statusMessage: String?
}

// 認証状態を管理するクラス
class AuthenticationService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: LineUser?
    @Published var accessToken: String?
    
    private let userDefaultsKey = "line_user_data"
    private let tokenKey = "line_access_token"
    
    init() {
        loadSavedUser()
    }
    
    func login(accessToken: String, user: LineUser) {
        // アクセストークンを保存
        self.accessToken = accessToken
        UserDefaults.standard.set(accessToken, forKey: tokenKey)
        
        // ユーザー情報を保存
        self.currentUser = user
        self.isAuthenticated = true
        saveUser(user)
    }
    
    func login(accessToken: String) async throws {
        // アクセストークンを保存
        self.accessToken = accessToken
        UserDefaults.standard.set(accessToken, forKey: tokenKey)
        
        // ユーザー情報を取得
        try await fetchUserProfile(accessToken: accessToken)
    }
    
    func fetchUserProfile(accessToken: String) async throws {
        guard let url = URL(string: "https://api.line.me/v2/profile") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.profileFetchFailed
        }
        
        let decoder = JSONDecoder()
        let profile = try decoder.decode(LineProfile.self, from: data)
        
        let user = LineUser(
            userId: profile.userId,
            displayName: profile.displayName,
            pictureUrl: profile.pictureUrl,
            statusMessage: profile.statusMessage
        )
        
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
        }
        
        saveUser(user)
    }
    
    func logout() {
        isAuthenticated = false
        currentUser = nil
        accessToken = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
    
    private func saveUser(_ user: LineUser) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func loadSavedUser() {
        if let savedData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(LineUser.self, from: savedData),
           let token = UserDefaults.standard.string(forKey: tokenKey) {
            self.currentUser = user
            self.accessToken = token
            self.isAuthenticated = true
        }
    }
}

// LINE APIのプロフィールレスポンス
struct LineProfile: Codable {
    let userId: String
    let displayName: String
    let pictureUrl: String?
    let statusMessage: String?
}

enum AuthError: Error {
    case invalidURL
    case profileFetchFailed
    case loginCancelled
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .profileFetchFailed:
            return "プロフィール取得に失敗しました"
        case .loginCancelled:
            return "ログインがキャンセルされました"
        }
    }
}