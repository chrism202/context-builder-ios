# Context Builder for iOS

Context Builder is a lightweight SwiftUI application and share extension that makes it effortless to capture any snippet of personal context from your iPhone. Highlight text, save images, or share links from any app into a single unified inbox that you can browse later.

## Features
- **Instant capture via the Share Sheet**: The "Save to Context Builder" extension accepts text, URLs, images, and arbitrary files.
- **Shared Store**: Items are persisted inside an App Group container so both the app and extension have access to the full history.
- **Organized viewer**: The main app presents a concise list with detail pages for each captured item, including previews for text and images and quick access to shared links.
- **Safe storage**: Binary attachments are stored alongside JSON metadata, keeping the data portable and easy to back up.
- **☁️ Cloud Sync** (NEW): Upload your saved context to AWS cloud storage via serverless infrastructure.
- **🤖 MCP Server** (NEW): Serve your context to AI assistants through the Model Context Protocol.

## Project Structure
- `ContextBuilder/` – SwiftUI application sources, assets, and entitlements.
- `ContextBuilderShareExtension/` – Share extension implementation and storyboard.
- `Shared/` – Shared models and storage layer reused by both targets.
- `backend/` – AWS serverless backend (Lambda, DynamoDB, S3) with MCP server implementation.
- `ContextBuilder.xcodeproj` – Xcode project configured with app group entitlements (`group.com.example.contextbuilder`).

## Getting Started

### Local Development (iOS Only)
1. Open `ContextBuilder.xcodeproj` in Xcode 15 or newer.
2. Update the bundle identifiers and App Group (`SharedConstants.appGroupIdentifier`) to values you control.
3. Select the `ContextBuilder` scheme and run on an iOS 16+ simulator or device.
4. To test the share extension on device:
   - Deploy the app to your device.
   - Open the iOS share sheet on any text, image, or link.
   - Tap **Save to Context Builder**. The item will appear in the app's main list.

### Cloud Setup (Optional)
To enable cloud sync and MCP server functionality:

1. **Deploy the backend**: See [`backend/README.md`](backend/README.md) for AWS deployment instructions
2. **Configure the iOS app**: See [`CLOUD_SETUP.md`](CLOUD_SETUP.md) for complete setup guide
3. **Set up MCP server**: Configure your AI assistant to access your saved context

Quick start:
```bash
cd backend
npm install
npm run build
sam deploy --guided
```

After deployment, configure the API endpoint in the iOS app Settings (⚙️ icon).

## Persistence Model
- Metadata is stored in `context-items.json` inside the shared container (`Library/Application Support/ContextBuilder/`).
- Attachments are written to an `attachments/` folder using deterministic filenames derived from the item UUID.
- `ContextStorage` exposes async helpers so the share extension can add entries without blocking its UI thread.

## Next Steps & Ideas
1. **Bucketing & Organization** – Introduce background categorisation (e.g., rule-based or ML-based clustering) to group related context.
2. **Search & Filtering** – Add full-text search for snippets and filter by date, source app, or content type.
3. **✅ Cloud Sync** – AWS serverless backend with upload functionality (implemented!)
4. **✅ MCP Server** – Serve context to AI assistants via Model Context Protocol (implemented!)
5. **Authentication** – Add user authentication (AWS Cognito) for multi-user support.
6. **Automatic Sync** – Background sync when app enters foreground.
7. **Bi-directional Sync** – Download context from cloud to device.
8. **Rich Previews** – Fetch link metadata, generate image thumbnails, and display adaptive cards in the list view.
9. **Privacy Controls** – Add quick delete, bulk export, and passcode/Face ID gating for the context vault.

## Requirements
- Xcode 15+
- iOS 16.0 deployment target (can be lowered if desired)
- Swift 5.9 toolchain

The project is intentionally simple so you can extend the capture flow or experiment with new context-driven experiences.
