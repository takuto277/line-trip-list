import Foundation

struct Config {
    // LINE API設定
    struct LineAPI {
        static let channelToken = ProcessInfo.processInfo.environment["LINE_CHANNEL_TOKEN"] ?? ""
        static let channelSecret = ProcessInfo.processInfo.environment["LINE_CHANNEL_SECRET"] ?? ""
        static let channelID = ProcessInfo.processInfo.environment["LINE_CHANNEL_ID"] ?? ""
        static let userID = ProcessInfo.processInfo.environment["LINE_USER_ID"] ?? ""
        static let webhookURL = ProcessInfo.processInfo.environment["LINE_WEBHOOK_URL"] ?? ""
        static let groupID = ProcessInfo.processInfo.environment["LINE_GROUP_ID"] ?? ""
    }
}

// デバッグ用の設定確認
#if DEBUG
extension Config {
    static func validateConfiguration() {
        print("🔑 Configuration Check:")
        print("Channel Token: \(LineAPI.channelToken.isEmpty ? "❌ Missing" : "✅ Set")")
        print("Channel Secret: \(LineAPI.channelSecret.isEmpty ? "❌ Missing" : "✅ Set")")
        print("Channel ID: \(LineAPI.channelID.isEmpty ? "❌ Missing" : "✅ Set")")
        print("User ID: \(LineAPI.userID.isEmpty ? "❌ Missing" : "✅ Set")")
        print("Webhook URL: \(LineAPI.webhookURL.isEmpty ? "❌ Missing" : "✅ Set")")
        print("Group ID: \(LineAPI.groupID.isEmpty ? "❌ Missing" : "✅ Set")")
    }
}
#endif
