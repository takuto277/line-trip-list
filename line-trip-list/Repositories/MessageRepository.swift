import Foundation
import SwiftData

/// Repositoryプロトコル：メッセージの取得・送信・永続化を抽象化
protocol MessageRepository: AnyObject {
    func fetchMessages(lineId: String?) async
    func sendMessage(to groupId: String, text: String) async throws
    func persistMessages(into context: ModelContext) async
    // mutable to allow UI edits to previewImageURL in LinksView
    var receivedMessages: [LineMessage] { get set }
    var extractedLinks: [LineMessageService.LinkItem] { get set }
    var isLoading: Bool { get }
}
