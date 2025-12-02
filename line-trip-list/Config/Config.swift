import Foundation

struct Config {
    // LINE Messaging API設定（Webhook・メッセージ送信用）
    struct MessagingAPI {
        static let channelToken = ProcessInfo.processInfo.environment["LINE_MESSAGING_TOKEN"] ?? ""
        static let channelSecret = ProcessInfo.processInfo.environment["LINE_MESSAGING_SECRET"] ?? ""
        static let groupID = ProcessInfo.processInfo.environment["LINE_GROUP_ID"] ?? ""
    }
    
    // LINE Login設定（ユーザー認証用）
    struct LoginAPI {
        static let channelID = ProcessInfo.processInfo.environment["LINE_LOGIN_CHANNEL_ID"] ?? ""
    }
}

// デバッグ用の設定確認
#if DEBUG
extension Config {
    static func validateConfiguration() {
        print("🔑 Configuration Check:")
        print("📨 Messaging API:")
        print("  Token: \(MessagingAPI.channelToken.isEmpty ? "❌ Missing" : "✅ Set")")
        print("  Secret: \(MessagingAPI.channelSecret.isEmpty ? "❌ Missing" : "✅ Set")")
        print("  Group ID: \(MessagingAPI.groupID.isEmpty ? "❌ Missing" : "✅ Set")")
        print("🔐 Login API:")
        print("  Channel ID: \(LoginAPI.channelID.isEmpty ? "❌ Missing" : "✅ Set")")
    }
}
#endif
