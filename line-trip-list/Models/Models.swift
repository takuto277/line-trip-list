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

@Model
final class UserDisplayName {
    @Attribute(.unique) var id: String
    var userId: String
    var displayName: String

    init(id: String = UUID().uuidString, userId: String, displayName: String) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
    }
}

@Model
final class PreviewOverride {
    @Attribute(.unique) var id: String
    var linkUrl: String
    var overrideImageUrl: String
    var title: String?
    var createdAt: Date

    init(id: String = UUID().uuidString, linkUrl: String, overrideImageUrl: String, title: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.linkUrl = linkUrl
        self.overrideImageUrl = overrideImageUrl
        self.title = title
        self.createdAt = createdAt
    }
}
