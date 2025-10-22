import Foundation

/// Service for uploading context items to the cloud backend
class ContextUploadService {
    static let shared = ContextUploadService()

    /// Backend API endpoint - configure this to your deployed API endpoint
    private var apiEndpoint: String {
        // Try to read from UserDefaults first, otherwise use default
        return UserDefaults.standard.string(forKey: "apiEndpoint") ?? ""
    }

    private init() {}

    /// Upload context items to the cloud backend
    /// - Parameters:
    ///   - items: Array of context items to upload
    ///   - storage: ContextStorage instance for reading attachment data
    ///   - completion: Completion handler with success status and error if any
    func uploadItems(
        _ items: [ContextItem],
        storage: ContextStorage,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        guard !apiEndpoint.isEmpty else {
            completion(false, UploadError.noEndpointConfigured)
            return
        }

        guard let url = URL(string: "\(apiEndpoint)/upload") else {
            completion(false, UploadError.invalidEndpoint)
            return
        }

        // Build request payload
        var uploadItems: [[String: Any]] = []

        for item in items {
            var itemDict: [String: Any] = [
                "kind": item.kind.rawValue,
            ]

            if let sourceApp = item.sourceAppBundleID {
                itemDict["sourceAppBundleID"] = sourceApp
            }

            if let text = item.text {
                itemDict["text"] = text
            }

            if let url = item.url {
                itemDict["url"] = url.absoluteString
            }

            // Handle attachments
            if let attachmentURL = storage.attachmentURL(for: item),
               let attachmentData = try? Data(contentsOf: attachmentURL) {
                itemDict["attachmentData"] = attachmentData.base64EncodedString()

                if let contentType = item.attachmentContentType {
                    itemDict["attachmentContentType"] = contentType
                }

                if let filename = item.originalFilename {
                    itemDict["originalFilename"] = filename
                }
            }

            uploadItems.append(itemDict)
        }

        let payload: [String: Any] = [
            "items": uploadItems,
            "userId": "default"
        ]

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(false, UploadError.serializationError(error))
            return
        }

        // Send request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, UploadError.networkError(error))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(false, UploadError.invalidResponse)
                }
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    completion(false, UploadError.serverError(httpResponse.statusCode))
                }
                return
            }

            // Parse response
            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = json["success"] as? Bool {
                        DispatchQueue.main.async {
                            completion(success, nil)
                        }
                        return
                    }
                } catch {
                    print("Failed to parse response: \(error)")
                }
            }

            DispatchQueue.main.async {
                completion(true, nil)
            }
        }.resume()
    }

    /// Upload a single context item
    func uploadItem(
        _ item: ContextItem,
        storage: ContextStorage,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        uploadItems([item], storage: storage, completion: completion)
    }
}

// MARK: - Upload Errors

enum UploadError: LocalizedError {
    case noEndpointConfigured
    case invalidEndpoint
    case serializationError(Error)
    case networkError(Error)
    case invalidResponse
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .noEndpointConfigured:
            return "No API endpoint configured. Please set the endpoint in Settings."
        case .invalidEndpoint:
            return "Invalid API endpoint URL"
        case .serializationError(let error):
            return "Failed to serialize request: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: HTTP \(code)"
        }
    }
}
