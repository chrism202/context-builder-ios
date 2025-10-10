import Foundation
import UniformTypeIdentifiers

enum ContextItemKind: String, Codable, CaseIterable {
    case text
    case url
    case image
    case file
}

struct ContextItem: Identifiable, Codable {
    var id: UUID
    var createdAt: Date
    var kind: ContextItemKind
    var sourceAppBundleID: String?
    var text: String?
    var url: URL?
    var attachmentFileName: String?
    var attachmentContentType: String?
    var originalFilename: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        kind: ContextItemKind,
        sourceAppBundleID: String? = nil,
        text: String? = nil,
        url: URL? = nil,
        attachmentFileName: String? = nil,
        attachmentContentType: String? = nil,
        originalFilename: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.sourceAppBundleID = sourceAppBundleID
        self.text = text
        self.url = url
        self.attachmentFileName = attachmentFileName
        self.attachmentContentType = attachmentContentType
        self.originalFilename = originalFilename
    }
}

extension ContextItem {
    var displayTitle: String {
        switch kind {
        case .text:
            let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? "Text Snippet" : String(trimmed.prefix(60))
        case .url:
            return url?.absoluteString ?? "Link"
        case .image:
            return originalFilename ?? "Image"
        case .file:
            return originalFilename ?? "File"
        }
    }

    var metadataSummary: String {
        var parts: [String] = []
        if let sourceAppBundleID {
            parts.append(sourceAppBundleID)
        }
        parts.append(DateFormatter.mediumFormatter.string(from: createdAt))
        return parts.joined(separator: " • ")
    }
}

private extension DateFormatter {
    static let mediumFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
