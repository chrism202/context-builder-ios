import SwiftUI

struct ContextListView: View {
    @ObservedObject var viewModel: ContextViewModel

    var body: some View {
        Group {
            if viewModel.items.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Context Vault")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: viewModel.refresh) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }

    private var list: some View {
        List {
            ForEach(viewModel.items) { item in
                NavigationLink(value: item.id) {
                    ContextRow(item: item)
                }
            }
            .onDelete(perform: viewModel.deleteItems)
        }
        .refreshable { viewModel.refresh() }
        .navigationDestination(for: UUID.self) { id in
            if let item = viewModel.items.first(where: { $0.id == id }) {
                ContextDetailView(item: item, attachmentURL: viewModel.attachmentURL(for: item))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No saved context yet")
                .font(.title3)
            Text("Share any text, image, or link using the Context Builder share sheet to store it here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct ContextRow: View {
    let item: ContextItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.displayTitle)
                .font(.headline)
                .lineLimit(2)
            if let text = item.text, item.kind == .text {
                Text(text)
                    .font(.subheadline)
                    .lineLimit(3)
                    .foregroundStyle(.secondary)
            }
            Text(item.metadataSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ContextListView_Previews: PreviewProvider {
    static var previews: some View {
        let sample = ContextItem(
            kind: .text,
            sourceAppBundleID: "com.apple.MobileSafari",
            text: "Sample text",
            originalFilename: nil
        )
        ContextListView(viewModel: ContextViewModel(initialItems: [sample]))
    }
}
