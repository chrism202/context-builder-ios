import Foundation
import UniformTypeIdentifiers

final class ContextStorage {
    static let shared = ContextStorage()

    private let fileManager: FileManager
    private let containerURL: URL
    private let metadataURL: URL
    private let attachmentsURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue = DispatchQueue(label: "contextbuilder.storage", qos: .userInitiated)

    private init() {
        fileManager = FileManager.default
        let baseURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.appGroupIdentifier)
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        containerURL = baseURL.appendingPathComponent(SharedConstants.containerDirectoryName, isDirectory: true)
        metadataURL = containerURL.appendingPathComponent(SharedConstants.metadataFileName)
        attachmentsURL = containerURL.appendingPathComponent(SharedConstants.attachmentsDirectoryName, isDirectory: true)

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()

        do {
            try fileManager.createDirectory(at: containerURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: attachmentsURL, withIntermediateDirectories: true)
        } catch {
            NSLog("ContextStorage failed to prepare directories: \(error)")
        }
    }

    func loadItems() -> [ContextItem] {
        queue.sync {
            self.loadItemsUnlocked()
        }
    }

    func appendText(_ text: String, sourceApp: String?, completion: ((Result<ContextItem, Error>) -> Void)? = nil) {
        let sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else {
            completion?(.failure(StorageError.emptyPayload))
            return
        }
        let item = ContextItem(kind: .text, sourceAppBundleID: sourceApp, text: sanitized)
        append(item, attachmentData: nil, attachmentTypeIdentifier: nil, originalFilename: nil, completion: completion)
    }

    func appendURL(_ url: URL, sourceApp: String?, completion: ((Result<ContextItem, Error>) -> Void)? = nil) {
        let item = ContextItem(kind: .url, sourceAppBundleID: sourceApp, url: url)
        append(item, attachmentData: nil, attachmentTypeIdentifier: nil, originalFilename: nil, completion: completion)
    }

    func appendBinary(
        _ data: Data,
        typeIdentifier: String?,
        originalFilename: String?,
        sourceApp: String?,
        completion: ((Result<ContextItem, Error>) -> Void)? = nil
    ) {
        let item = ContextItem(
            kind: typeIdentifier.flatMap { UTType($0)?.conforms(to: .image) } == true ? .image : .file,
            sourceAppBundleID: sourceApp,
            attachmentContentType: typeIdentifier,
            originalFilename: originalFilename
        )
        append(item, attachmentData: data, attachmentTypeIdentifier: typeIdentifier, originalFilename: originalFilename, completion: completion)
    }

    func attachmentURL(for item: ContextItem) -> URL? {
        guard let filename = item.attachmentFileName else { return nil }
        return attachmentsURL.appendingPathComponent(filename, isDirectory: false)
    }

    func delete(_ item: ContextItem) {
        queue.async {
            var items = self.loadItemsUnlocked()
            items.removeAll { $0.id == item.id }
            self.persist(items)
            if let fileURL = self.attachmentURL(for: item) {
                try? self.fileManager.removeItem(at: fileURL)
            }
        }
    }

    private func append(
        _ item: ContextItem,
        attachmentData: Data?,
        attachmentTypeIdentifier: String?,
        originalFilename: String?,
        completion: ((Result<ContextItem, Error>) -> Void)?
    ) {
        queue.async {
            var newItem = item
            if let attachmentData {
                let fileExtension = self.fileExtension(for: attachmentTypeIdentifier, originalFilename: originalFilename)
                let fileName = "\(newItem.id.uuidString).\(fileExtension)"
                let fileURL = self.attachmentsURL.appendingPathComponent(fileName, isDirectory: false)
                do {
                    try attachmentData.write(to: fileURL, options: .atomic)
                    newItem.attachmentFileName = fileName
                } catch {
                    DispatchQueue.main.async {
                        completion?(.failure(error))
                    }
                    return
                }
            }

            var items = self.loadItemsUnlocked()
            items.insert(newItem, at: 0)
            self.persist(items)
            DispatchQueue.main.async {
                completion?(.success(newItem))
            }
        }
    }

    private func persist(_ items: [ContextItem]) {
        do {
            let data = try encoder.encode(items)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            NSLog("ContextStorage failed to persist items: \(error)")
        }
    }

    private func loadItemsUnlocked() -> [ContextItem] {
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: metadataURL)
            let items = try decoder.decode([ContextItem].self, from: data)
            return items.sorted(by: { $0.createdAt > $1.createdAt })
        } catch {
            NSLog("ContextStorage failed to decode items: \(error)")
            return []
        }
    }

    private func fileExtension(for typeIdentifier: String?, originalFilename: String?) -> String {
        if let originalFilename, let ext = URL(fileURLWithPath: originalFilename).pathExtension, !ext.isEmpty {
            return ext
        }
        if let typeIdentifier, let type = UTType(typeIdentifier), let preferredExt = type.preferredFilenameExtension {
            return preferredExt
        }
        return "dat"
    }

    enum StorageError: Error {
        case emptyPayload
    }
}

extension ContextStorage {
    func appendText(_ text: String, sourceApp: String?) async throws -> ContextItem {
        try await withCheckedThrowingContinuation { continuation in
            appendText(text, sourceApp: sourceApp) { result in
                continuation.resume(with: result)
            }
        }
    }

    func appendURL(_ url: URL, sourceApp: String?) async throws -> ContextItem {
        try await withCheckedThrowingContinuation { continuation in
            appendURL(url, sourceApp: sourceApp) { result in
                continuation.resume(with: result)
            }
        }
    }

    func appendBinary(
        _ data: Data,
        typeIdentifier: String?,
        originalFilename: String?,
        sourceApp: String?
    ) async throws -> ContextItem {
        try await withCheckedThrowingContinuation { continuation in
            appendBinary(data, typeIdentifier: typeIdentifier, originalFilename: originalFilename, sourceApp: sourceApp) { result in
                continuation.resume(with: result)
            }
        }
    }
}
