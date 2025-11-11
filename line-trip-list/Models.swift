import Foundation
import SwiftData

@Model
final class LinkPreview {
    @Attribute(.unique) var id: String
    var url: String
    var title: String?
    var descriptionText: String?
    var imageUrl: String?
    var resolvedAt: Date

    init(id: String = UUID().uuidString, url: String, title: String? = nil, descriptionText: String? = nil, imageUrl: String? = nil, resolvedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.title = title
        self.descriptionText = descriptionText
        self.imageUrl = imageUrl
        self.resolvedAt = resolvedAt
    }
}

@Model
final class Message {
    @Attribute(.unique) var id: String
    var lineId: String
    var text: String
    var createdAt: Date
    var preview: LinkPreview?

    init(id: String = UUID().uuidString, lineId: String, text: String, createdAt: Date = Date(), preview: LinkPreview? = nil) {
        self.id = id
        self.lineId = lineId
        self.text = text
        self.createdAt = createdAt
        self.preview = preview
    }
}
