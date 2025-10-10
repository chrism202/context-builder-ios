import Foundation

@MainActor
final class ContextViewModel: ObservableObject {
    @Published private(set) var items: [ContextItem]

    private let storage: ContextStorage

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

    private func loadItems() async -> [ContextItem] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let loaded = self.storage.loadItems()
                continuation.resume(returning: loaded)
            }
        }
    }
}
