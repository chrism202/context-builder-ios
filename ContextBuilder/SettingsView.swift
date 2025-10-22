import SwiftUI

struct SettingsView: View {
    @AppStorage("apiEndpoint") private var apiEndpoint: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("API Endpoint URL", text: $apiEndpoint)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                } header: {
                    Text("Cloud Sync")
                } footer: {
                    Text("Enter your AWS API Gateway endpoint URL (e.g., https://abc123.execute-api.us-east-1.amazonaws.com/dev)")
                }

                Section {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(apiEndpoint.isEmpty)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Cloud Sync")
                            .font(.headline)
                        Text("Upload your saved context to the cloud and access it via an MCP server for AI assistants.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func testConnection() {
        guard let url = URL(string: "\(apiEndpoint)/list?userId=default&limit=1") else {
            return
        }

        URLSession.shared.dataTask(with: url) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Connection test failed: \(error)")
                } else if let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) {
                    print("Connection test successful!")
                }
            }
        }.resume()
    }
}

#Preview {
    SettingsView()
}
