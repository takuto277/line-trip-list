import Foundation
import Combine

// LINEメッセージの構造体
struct LineMessage: Codable {
    // id は API により無い場合があるため Optional にする
    let id: Int?
    let groupId: String?  // group_id から変更
    let userId: String?   // user_id から変更
    let message: String
    let userName: String  // user_name から変更
    let timestamp: Int64
    let createdAt: String? // created_at から変更（Optional）
    
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
    // messages が null になる場合があるため Optional にする
    let messages: [LineMessage]?
    let count: Int?
}

// LINE Webhook受信用のサービス
class LineMessageService: ObservableObject {
    @Published var receivedMessages: [LineMessage] = []
    @Published var isConnected = false
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    // API の base URL を vercel のデプロイ先に変更
    private let baseURL = "https://line-trip-list-api.vercel.app/api"
    
    init() {
        fetchMessages() // 起動時にメッセージを取得
    }
    
    // メッセージを取得
    // lineId: 任意。指定するとその user_id に一致するメッセージのみ取得する
    func fetchMessages(lineId: String? = nil) async {
        await MainActor.run {
            isLoading = true
        }
        var urlString = "\(baseURL)/messages"
        if let lineId = lineId, !lineId.isEmpty {
            // percent-encode
            if let encoded = lineId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?line_id=\(encoded)"
            } else {
                urlString += "?line_id=\(lineId)"
            }
        }

        guard let url = URL(string: urlString) else {
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

                let decodedMessages = messagesResponse.messages ?? []

                await MainActor.run {
                    self.receivedMessages = decodedMessages.sorted { $0.timestamp > $1.timestamp }
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
