import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!

    private let storage = ContextStorage.shared

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Task { [weak self] in
            await self?.processSharedItems()
        }
    }

    @MainActor
    private func updateStatus(_ message: String, isLoading: Bool) {
        statusLabel.text = message
        if isLoading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    private func processSharedItems() async {
        await updateStatus("Saving to Context Builder…", isLoading: true)

        guard let extensionContext else {
            await updateStatus("Unable to access shared content", isLoading: false)
            return
        }

        let sourceApp = extensionContext.sourceApplicationBundleIdentifier
        let providers = extensionContext.inputItems.compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }

        guard !providers.isEmpty else {
            await updateStatus("Nothing to save", isLoading: false)
            completeRequest()
            return
        }

        var savedCount = 0
        var encounteredErrors: [Error] = []

        for provider in providers {
            do {
                if let text = try await loadText(from: provider) {
                    _ = try await storage.appendText(text, sourceApp: sourceApp)
                    savedCount += 1
                    continue
                }

                if let url = try await loadURL(from: provider) {
                    _ = try await storage.appendURL(url, sourceApp: sourceApp)
                    savedCount += 1
                    continue
                }

                if let (data, typeIdentifier) = try await loadImageData(from: provider) {
                    _ = try await storage.appendBinary(
                        data,
                        typeIdentifier: typeIdentifier,
                        originalFilename: provider.suggestedName,
                        sourceApp: sourceApp
                    )
                    savedCount += 1
                    continue
                }

                if let (data, typeIdentifier) = try await loadFileData(from: provider) {
                    _ = try await storage.appendBinary(
                        data,
                        typeIdentifier: typeIdentifier,
                        originalFilename: provider.suggestedName,
                        sourceApp: sourceApp
                    )
                    savedCount += 1
                    continue
                }
            } catch {
                encounteredErrors.append(error)
            }
        }

        await finalizeProcessing(savedCount: savedCount, errors: encounteredErrors)
    }

    @MainActor
    private func finalizeProcessing(savedCount: Int, errors: [Error]) {
        if savedCount > 0 {
            let suffix = savedCount == 1 ? "item" : "items"
            updateStatus("Saved \(savedCount) \(suffix)", isLoading: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                self.completeRequest()
            }
        } else {
            let message = errors.isEmpty ? "Nothing captured" : "Unable to save shared content"
            updateStatus(message, isLoading: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.completeRequest()
            }
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func loadText(from provider: NSItemProvider) async throws -> String? {
        let textTypes: [UTType] = [.plainText, .utf8PlainText, .text]
        for type in textTypes {
            guard provider.hasItemConformingToTypeIdentifier(type.identifier) else { continue }
            if let item = try await loadItem(for: type, from: provider) {
                if let string = item as? String {
                    return string
                }
                if let attributed = item as? NSAttributedString {
                    return attributed.string
                }
                if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                    return string
                }
            }
        }
        return nil
    }

    private func loadURL(from provider: NSItemProvider) async throws -> URL? {
        let urlTypes: [UTType] = [.url, .fileURL, .data]
        for type in urlTypes {
            guard provider.hasItemConformingToTypeIdentifier(type.identifier) else { continue }
            if let item = try await loadItem(for: type, from: provider) {
                if let url = item as? URL {
                    return url
                }
                if let data = item as? Data, let string = String(data: data, encoding: .utf8), let url = URL(string: string) {
                    return url
                }
            }
        }
        return nil
    }

    private func loadImageData(from provider: NSItemProvider) async throws -> (Data, String)? {
        let imageTypes: [UTType] = [.png, .jpeg, .heic, .image]
        for type in imageTypes {
            guard provider.hasItemConformingToTypeIdentifier(type.identifier) else { continue }
            if let item = try await loadItem(for: type, from: provider) {
                if let url = item as? URL {
                    let data = try Data(contentsOf: url)
                    return (data, type.identifier)
                }
                if let data = item as? Data {
                    return (data, type.identifier)
                }
                if let image = item as? UIImage, let data = image.pngData() {
                    return (data, UTType.png.identifier)
                }
            }
        }
        return nil
    }

    private func loadFileData(from provider: NSItemProvider) async throws -> (Data, String)? {
        for typeIdentifier in provider.registeredTypeIdentifiers {
            let type = UTType(typeIdentifier) ?? .data
            guard provider.hasItemConformingToTypeIdentifier(type.identifier) else { continue }
            if let item = try await loadItem(for: type, from: provider) {
                if let url = item as? URL {
                    return (try Data(contentsOf: url), type.identifier)
                }
                if let data = item as? Data {
                    return (data, type.identifier)
                }
            }
        }
        return nil
    }

    private func loadItem(for type: UTType, from provider: NSItemProvider) async throws -> NSSecureCoding? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: item)
                }
            }
        }
    }
}
