import Foundation
import SwiftData
import Combine
import SwiftUI

@MainActor
final class DisplayNameStore: ObservableObject {
    @Published private(set) var overrides: [String: String] = [:]
    private let key = "displayNameOverrides"

    init() {
        load()
    }

    func load() {
        // load from SwiftData using Persistence helper
    let context = ModelContext(container: Persistence.shared)
    let users = Persistence.fetchAllUserDisplayNames(from: context)
        var dict: [String: String] = [:]
        for u in users {
            dict[u.userId] = u.displayName
        }
        overrides = dict
    }

    private func persist() {
        // persisted via SwiftData in setOverride/removeOverride
    }

    func setOverride(_ name: String, for userId: String) {
        if name.isEmpty {
            overrides.removeValue(forKey: userId)
        } else {
            overrides[userId] = name
        }
        // persist to SwiftData
    let context = ModelContext(container: Persistence.shared)
        Persistence.upsertUserDisplayName(userId: userId, displayName: name, into: context)
    }

    func removeOverride(for userId: String) {
        overrides.removeValue(forKey: userId)
        let context = ModelContext(container: Persistence.shared)
        // upsert empty -> remove
        if let existing = (try? context.fetch(FetchDescriptor<UserDisplayName>()).first(where: { $0.userId == userId })) {
            context.delete(existing)
            try? context.save()
        }
    }

    func binding(for userId: String) -> Binding<String> {
        Binding(get: { self.overrides[userId] ?? "" }, set: { self.setOverride($0, for: userId) })
    }

    func displayName(for userId: String?, fallback: String) -> String {
        guard let id = userId else { return fallback }
        return overrides[id] ?? fallback
    }

    // Add discovered userIds if not present in overrides (persist as empty display name)
    func addDiscoveredUserIds(_ userIds: [String?]) {
        let context = ModelContext(container: Persistence.shared)
        var changed = false
        for maybe in userIds {
            guard let uid = maybe else { continue }
            if overrides[uid] == nil {
                overrides[uid] = ""
                Persistence.upsertUserDisplayName(userId: uid, displayName: "", into: context)
                changed = true
            }
        }
        if changed {
            // ensure UI updates
            objectWillChange.send()
        }
    }
}
