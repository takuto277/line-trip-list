import Foundation
import SwiftData

struct Persistence {
    static let shared: ModelContainer = {
        let schema = Schema([Message.self, LinkPreview.self, UserDisplayName.self, PreviewOverride.self])
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
            // Fetch existing Message by id using a FetchDescriptor to satisfy generic requirements
            if let existing = try? context.fetch(FetchDescriptor<Message>(predicate: #Predicate { $0.id == id })).first {
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

    static func fetchAllUserDisplayNames(from context: ModelContext) -> [UserDisplayName] {
        do {
            return try context.fetch(FetchDescriptor<UserDisplayName>())
        } catch {
            print("⚠️ Failed to fetch UserDisplayName: \(error)")
            return []
        }
    }

    static func upsertUserDisplayName(userId: String, displayName: String, into context: ModelContext) {
        // try to find existing by userId
        if let existing = (try? context.fetch(FetchDescriptor<UserDisplayName>()).first(where: { $0.userId == userId })) {
            existing.displayName = displayName
        } else {
            let u = UserDisplayName(userId: userId, displayName: displayName)
            context.insert(u)
        }
        do {
            try context.save()
        } catch {
            print("⚠️ Failed to upsert UserDisplayName: \(error)")
        }
    }

    static func upsertPreviewOverride(linkUrl: String, overrideImageUrl: String, into context: ModelContext) {
        if let existing = (try? context.fetch(FetchDescriptor<PreviewOverride>()).first(where: { $0.linkUrl == linkUrl })) {
            existing.overrideImageUrl = overrideImageUrl
            existing.createdAt = Date()
        } else {
            let p = PreviewOverride(linkUrl: linkUrl, overrideImageUrl: overrideImageUrl)
            context.insert(p)
        }
        do {
            try context.save()
        } catch {
            print("⚠️ Failed to upsert PreviewOverride: \(error)")
        }
    }

    static func fetchPreviewOverride(for linkUrl: String, from context: ModelContext) -> PreviewOverride? {
        do {
            let all = try context.fetch(FetchDescriptor<PreviewOverride>())
            return all.first(where: { $0.linkUrl == linkUrl })
        } catch {
            print("⚠️ Failed to fetch PreviewOverride: \(error)")
            return nil
        }
    }

    // variant that returns title and url together for convenience
    static func fetchPreviewOverrideValues(for linkUrl: String, from context: ModelContext) -> (imageUrl: String, title: String?)? {
        if let p = fetchPreviewOverride(for: linkUrl, from: context) {
            return (p.overrideImageUrl, p.title)
        }
        return nil
    }
}
