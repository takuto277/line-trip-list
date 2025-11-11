import Foundation
import SwiftData

struct Persistence {
    static let shared: ModelContainer = {
        let schema = Schema([Message.self, LinkPreview.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    static func saveMessageDTOs(_ messages: [LineMessage], into context: ModelContext) {
        for m in messages {
            // use server id if present, otherwise uuid
            let id = m.id.map { String($0) } ?? UUID().uuidString
            // check for existing
            if let existing = try? context.fetch(Message.self, where: #Predicate { $0.id == id }).first {
                // update fields
                existing.text = m.message
                existing.lineId = m.userId ?? ""
                existing.createdAt = Date(timeIntervalSince1970: TimeInterval(m.timestamp / 1000))
            } else {
                let msg = Message(id: id, lineId: m.userId ?? "", text: m.message, createdAt: Date(timeIntervalSince1970: TimeInterval(m.timestamp / 1000)))
                context.insert(msg)
            }
        }
        do {
            try context.save()
        } catch {
            print("⚠️ Failed to save messages: \(error)")
        }
    }
}
