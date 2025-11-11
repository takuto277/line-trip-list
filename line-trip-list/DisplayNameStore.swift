import Foundation
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
        if let data = UserDefaults.standard.data(forKey: key), let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            overrides = dict
        } else {
            overrides = [:]
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(overrides) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func setOverride(_ name: String, for userId: String) {
        if name.isEmpty {
            overrides.removeValue(forKey: userId)
        } else {
            overrides[userId] = name
        }
        persist()
    }

    func removeOverride(for userId: String) {
        overrides.removeValue(forKey: userId)
        persist()
    }

    func binding(for userId: String) -> Binding<String> {
        Binding(get: { self.overrides[userId] ?? "" }, set: { self.setOverride($0, for: userId) })
    }

    func displayName(for userId: String?, fallback: String) -> String {
        guard let id = userId else { return fallback }
        return overrides[id] ?? fallback
    }
}
