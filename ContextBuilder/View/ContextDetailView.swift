import SwiftUI
import UIKit

struct ContextDetailView: View {
    let item: ContextItem
    let attachmentURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                payload
                metadata
            }
            .padding()
        }
        .navigationTitle(item.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.metadataSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let bundleID = item.sourceAppBundleID {
                Text("From: \(bundleID)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var payload: some View {
        switch item.kind {
        case .text:
            Text(item.text ?? "")
                .font(.body)
        case .url:
            if let url = item.url {
                Link(destination: url) {
                    Label(url.absoluteString, systemImage: "link")
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
        case .image:
            if let image = loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .shadow(radius: 4)
            } else {
                Text("Unable to load image")
                    .foregroundStyle(.secondary)
            }
        case .file:
            VStack(alignment: .leading, spacing: 8) {
                Label(item.originalFilename ?? "File", systemImage: "doc")
                if let url = attachmentURL {
                    Text(url.lastPathComponent)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Captured")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(item.createdAt, style: .date)
            Text(item.createdAt, style: .time)
        }
        .padding(.top, 24)
    }

    private func loadImage() -> UIImage? {
        guard let attachmentURL else { return nil }
        return UIImage(contentsOfFile: attachmentURL.path)
    }
}

struct ContextDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ContextDetailView(
            item: ContextItem(kind: .text, text: "Example", originalFilename: nil),
            attachmentURL: nil
        )
    }
}
