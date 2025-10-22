import Foundation

@MainActor
final class ContextViewModel: ObservableObject {
    @Published private(set) var items: [ContextItem]
    @Published var isUploading: Bool = false
    @Published var uploadError: Error?
    @Published var lastUploadDate: Date?

    private let storage: ContextStorage
    private let uploadService = ContextUploadService.shared

    init(storage: ContextStorage = .shared, initialItems: [ContextItem] = []) {
        self.storage = storage
        self.items = initialItems
        if initialItems.isEmpty {
            refresh()
        }
    }

    func refresh() {
        Task {
            let loaded = await loadItems()
            self.items = loaded
        }
    }

    func deleteItems(at offsets: IndexSet) {
        let targets = offsets.map { items[$0] }
        for index in offsets.sorted(by: >) {
            items.remove(at: index)
        }
        targets.forEach { storage.delete($0) }
    }

    func attachmentURL(for item: ContextItem) -> URL? {
        storage.attachmentURL(for: item)
    }

    /// Upload all context items to the cloud
    func uploadAllItems() {
        guard !isUploading else { return }

        isUploading = true
        uploadError = nil

        uploadService.uploadItems(items, storage: storage) { [weak self] success, error in
            guard let self = self else { return }

            self.isUploading = false

            if success {
                self.lastUploadDate = Date()
            } else {
                self.uploadError = error
            }
        }
    }

    /// Upload selected items to the cloud
    func uploadItems(at indices: IndexSet) {
        guard !isUploading else { return }

        let selectedItems = indices.map { items[$0] }
        isUploading = true
        uploadError = nil

        uploadService.uploadItems(selectedItems, storage: storage) { [weak self] success, error in
            guard let self = self else { return }

            self.isUploading = false

            if success {
                self.lastUploadDate = Date()
            } else {
                self.uploadError = error
            }
        }
    }

    private func loadItems() async -> [ContextItem] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let loaded = self.storage.loadItems()
                continuation.resume(returning: loaded)
            }
        }
    }
}
