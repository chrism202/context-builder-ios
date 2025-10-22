import SwiftUI

struct ContextListView: View {
    @ObservedObject var viewModel: ContextViewModel
    @State private var showingSettings = false
    @State private var showingUploadAlert = false

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
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gear")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        viewModel.refresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    if !viewModel.items.isEmpty {
                        Button {
                            showingUploadAlert = true
                        } label: {
                            Label("Upload to Cloud", systemImage: "icloud.and.arrow.up")
                        }
                        .disabled(viewModel.isUploading)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert("Upload Context", isPresented: $showingUploadAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Upload All") {
                viewModel.uploadAllItems()
            }
        } message: {
            Text("Upload all \(viewModel.items.count) items to the cloud?")
        }
        .alert(
            "Upload Error",
            isPresented: .constant(viewModel.uploadError != nil),
            presenting: viewModel.uploadError
        ) { _ in
            Button("OK") {
                viewModel.uploadError = nil
            }
        } message: { error in
            Text(error.localizedDescription)
        }
        .overlay {
            if viewModel.isUploading {
                uploadingOverlay
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

    private var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("Uploading to Cloud...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray))
            )
        }
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
