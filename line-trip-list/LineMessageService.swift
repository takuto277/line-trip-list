import Foundation
import Combine

// LINEメッセージの構造体
struct LineMessage: Codable, Identifiable {
    let id: Int
    let groupId: String?  // group_id から変更
    let userId: String?   // user_id から変更
    let message: String
    let userName: String  // user_name から変更
    let timestamp: Int64
    let createdAt: String // created_at から変更
    
    // API レスポンス用の CodingKeys
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id" 
        case message
        case userName = "user_name"
        case timestamp
        case createdAt = "created_at"
    }
}

// API レスポンス用の構造体
struct MessagesResponse: Codable {
    let messages: [LineMessage]
    let count: Int
}

// LINE Webhook受信用のサービス
class LineMessageService: ObservableObject {
    @Published var receivedMessages: [LineMessage] = []
    @Published var isConnected = false
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    private let baseURL = "https://line-trip-list.vercel.app/api"
    
    init() {
        fetchMessages() // 起動時にメッセージを取得
    }
    
    // メッセージを取得
    func fetchMessages() async {
        await MainActor.run {
            isLoading = true
        }
        
        guard let url = URL(string: "\(baseURL)/messages") else {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                
                let messagesResponse = try JSONDecoder().decode(MessagesResponse.self, from: data)
                
                await MainActor.run {
                    self.receivedMessages = messagesResponse.messages.sorted { $0.timestamp > $1.timestamp }
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            print("❌ Error fetching messages: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    // 同期版（SwiftUIから呼び出し用）
    func fetchMessages() {
        Task {
            await fetchMessages()
        }
    }
    
    // メッセージを送信
    func sendMessage(to groupId: String, text: String) async throws {
        guard !Config.MessagingAPI.channelToken.isEmpty else {
            throw LineAPIError.missingToken
        }
        
        let url = URL(string: "\(baseURL)/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messageData: [String: Any] = [
            "group_id": groupId,
            "message": text
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: messageData)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            throw LineAPIError.sendFailed(httpResponse.statusCode)
        }
    }
}

enum LineAPIError: Error {
    case missingToken
    case sendFailed(Int)
    case fetchFailed(Int)
    
    var localizedDescription: String {
        switch self {
        case .missingToken:
            return "LINE Channel Tokenが設定されていません"
        case .sendFailed(let code):
            return "メッセージ送信に失敗しました (HTTP \(code))"
        case .fetchFailed(let code):
            return "メッセージ取得に失敗しました (HTTP \(code))"
        }
    }
}
