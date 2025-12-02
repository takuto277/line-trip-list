import Foundation
import SwiftData
import Combine

@MainActor
class MessagesViewModel: ObservableObject {
    @Published private(set) var messages: [LineMessage] = []
    @Published private(set) var links: [LineMessageService.LinkItem] = []
    @Published private(set) var isLoading: Bool = false

    private let repository: MessageRepository

    init(repository: MessageRepository) {
        self.repository = repository
        self.messages = repository.receivedMessages
        self.links = repository.extractedLinks
        self.isLoading = repository.isLoading
    }

    func refresh(lineId: String? = nil, into context: ModelContext) async {
        isLoading = true
        await repository.fetchMessages(lineId: lineId)
        await repository.persistMessages(into: context)
        // pull updated values
        self.messages = repository.receivedMessages
        self.links = repository.extractedLinks
        self.isLoading = repository.isLoading
        isLoading = false
    }

    func send(text: String, to groupId: String) async throws {
        try await repository.sendMessage(to: groupId, text: text)
    }
}
