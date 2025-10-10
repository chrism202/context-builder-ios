# Context Builder for iOS

Context Builder is a lightweight SwiftUI application and share extension that makes it effortless to capture any snippet of personal context from your iPhone. Highlight text, save images, or share links from any app into a single unified inbox that you can browse later.

## Features
- **Instant capture via the Share Sheet**: The "Save to Context Builder" extension accepts text, URLs, images, and arbitrary files.
- **Shared Store**: Items are persisted inside an App Group container so both the app and extension have access to the full history.
- **Organized viewer**: The main app presents a concise list with detail pages for each captured item, including previews for text and images and quick access to shared links.
- **Safe storage**: Binary attachments are stored alongside JSON metadata, keeping the data portable and easy to back up.

## Project Structure
- `ContextBuilder/` – SwiftUI application sources, assets, and entitlements.
- `ContextBuilderShareExtension/` – Share extension implementation and storyboard.
- `Shared/` – Shared models and storage layer reused by both targets.
- `ContextBuilder.xcodeproj` – Xcode project configured with app group entitlements (`group.com.example.contextbuilder`).

## Getting Started
1. Open `ContextBuilder.xcodeproj` in Xcode 15 or newer.
2. Update the bundle identifiers and App Group (`SharedConstants.appGroupIdentifier`) to values you control.
3. Select the `ContextBuilder` scheme and run on an iOS 16+ simulator or device.
4. To test the share extension on device:
   - Deploy the app to your device.
   - Open the iOS share sheet on any text, image, or link.
   - Tap **Save to Context Builder**. The item will appear in the app's main list.

## Persistence Model
- Metadata is stored in `context-items.json` inside the shared container (`Library/Application Support/ContextBuilder/`).
- Attachments are written to an `attachments/` folder using deterministic filenames derived from the item UUID.
- `ContextStorage` exposes async helpers so the share extension can add entries without blocking its UI thread.

## Next Steps & Ideas
1. **Bucketing & Organization** – Introduce background categorisation (e.g., rule-based or ML-based clustering) to group related context.
2. **Search & Filtering** – Add full-text search for snippets and filter by date, source app, or content type.
3. **Sync & Backup** – Consider iCloud Drive or CloudKit support for multi-device availability.
4. **Rich Previews** – Fetch link metadata, generate image thumbnails, and display adaptive cards in the list view.
5. **Privacy Controls** – Add quick delete, bulk export, and passcode/Face ID gating for the context vault.

## Requirements
- Xcode 15+
- iOS 16.0 deployment target (can be lowered if desired)
- Swift 5.9 toolchain

The project is intentionally simple so you can extend the capture flow or experiment with new context-driven experiences.
