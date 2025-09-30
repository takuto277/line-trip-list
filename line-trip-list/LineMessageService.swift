import Foundation
import Combine

// LINEメッセージの構造体
struct LineMessage: Codable {
    let id: String
    let type: String
    let text: String?
    let timestamp: TimeInterval
    let source: LineSource
}

struct LineSource: Codable {
    let type: String  // "group", "user", "room"
    let groupId: String?
    let userId: String?
}

// LINE Webhook受信用のサービス
class LineMessageService: ObservableObject {
    @Published var receivedMessages: [LineMessage] = []
    @Published var isConnected = false
    
    private var cancellables = Set<AnyCancellable>()
    private let baseURL = "https://api.line.me/v2/bot"
    
    // メッセージを送信
    func sendMessage(to groupId: String, text: String) async throws {
        guard !Config.LineAPI.channelToken.isEmpty else {
            throw LineAPIError.missingToken
        }
        
        let url = URL(string: "\(baseURL)/message/push")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.LineAPI.channelToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messageData: [String: Any] = [
            "to": groupId,
            "messages": [
                [
                    "type": "text",
                    "text": text
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: messageData)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            throw LineAPIError.sendFailed(httpResponse.statusCode)
        }
    }
    
    // グループ情報を取得
    func getGroupInfo(groupId: String) async throws -> [String: Any] {
        guard !Config.LineAPI.channelToken.isEmpty else {
            throw LineAPIError.missingToken
        }
        
        let url = URL(string: "\(baseURL)/group/\(groupId)/summary")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(Config.LineAPI.channelToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            throw LineAPIError.requestFailed(httpResponse.statusCode)
        }
        
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    // Webhookからのメッセージを処理（実際の実装では、サーバーサイドで処理してアプリに通知）
    func handleWebhookMessage(_ messageData: [String: Any]) {
        // この関数は、実際にはサーバーサイドからプッシュ通知やWebSocketで受信したデータを処理します
        guard let events = messageData["events"] as? [[String: Any]] else { return }
        
        for event in events {
            if let type = event["type"] as? String, type == "message",
               let message = event["message"] as? [String: Any],
               let messageType = message["type"] as? String, messageType == "text",
               let text = message["text"] as? String,
               let messageId = message["id"] as? String,
               let timestamp = event["timestamp"] as? TimeInterval,
               let source = event["source"] as? [String: Any] {
                
                let lineSource = LineSource(
                    type: source["type"] as? String ?? "",
                    groupId: source["groupId"] as? String,
                    userId: source["userId"] as? String
                )
                
                let lineMessage = LineMessage(
                    id: messageId,
                    type: messageType,
                    text: text,
                    timestamp: timestamp,
                    source: lineSource
                )
                
                DispatchQueue.main.async {
                    self.receivedMessages.append(lineMessage)
                }
            }
        }
    }
}

enum LineAPIError: Error {
    case missingToken
    case sendFailed(Int)
    case requestFailed(Int)
    
    var localizedDescription: String {
        switch self {
        case .missingToken:
            return "LINE Channel Tokenが設定されていません"
        case .sendFailed(let code):
            return "メッセージ送信に失敗しました (HTTP \(code))"
        case .requestFailed(let code):
            return "APIリクエストに失敗しました (HTTP \(code))"
        }
    }
}
