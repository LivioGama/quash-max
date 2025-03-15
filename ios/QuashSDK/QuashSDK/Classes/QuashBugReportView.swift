import SwiftUI

struct QuashBugReportView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - Properties
    
    private let screenshotURL: URL?
    private let deviceInfo: [String: String]
    private let customData: [String: Any]
    private let networkLogsURL: URL?
    private let apiClient = QuashAPIClient()
    
    @State private var description = "Describe the issue you're experiencing..."
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // MARK: - Initialization
    
    init(screenshotURL: URL?, deviceInfo: [String: String], customData: [String: Any], networkLogsURL: URL?) {
        self.screenshotURL = screenshotURL
        self.deviceInfo = deviceInfo
        self.customData = customData
        self.networkLogsURL = networkLogsURL
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Report a Bug")
                        .font(.headline)
                    Spacer()
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Screenshot image
                if let screenshotURL = screenshotURL, let uiImage = UIImage(contentsOfFile: screenshotURL.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                        .padding(.horizontal)
                }
                
                // Description text field
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $description)
                        .padding(4)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                        .onTapGesture {
                            if description == "Describe the issue you're experiencing..." {
                                description = ""
                            }
                        }
                    
                    if description.isEmpty {
                        Text("Describe the issue you're experiencing...")
                            .foregroundColor(.gray)
                            .padding(8)
                    }
                }
                .padding(.horizontal)
                
                // Submit button
                Button(action: submitReport) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Submit")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                .disabled(isSubmitting)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
            )
            .padding()
            .alert(isPresented: $showSuccessAlert) {
                Alert(
                    title: Text("Thank You!"),
                    message: Text("Your bug report has been submitted successfully."),
                    dismissButton: .default(Text("OK")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text("Failed to submit bug report: \(errorMessage)"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Actions
    
    private func submitReport() {
        // Don't submit if showing placeholder text
        if description == "Describe the issue you're experiencing..." {
            description = ""
        }
        
        // Prepare report data
        var reportData: [String: Any] = [
            "description": description,
            "device_info": deviceInfo,
            "custom_data": customData,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        isSubmitting = true
        
        // Upload report
        apiClient.uploadBugReport(
            reportData: reportData,
            screenshotURL: screenshotURL,
            networkLogsURL: networkLogsURL
        ) { success, error in
            DispatchQueue.main.async {
                isSubmitting = false
                
                if success {
                    showSuccessAlert = true
                } else {
                    errorMessage = error?.localizedDescription ?? "Unknown error"
                    showErrorAlert = true
                }
            }
        }
    }
}

struct QuashBugReportView_Previews: PreviewProvider {
    static var previews: some View {
        QuashBugReportView(
            screenshotURL: nil,
            deviceInfo: ["device_model": "iPhone 13"],
            customData: ["user_id": "12345"],
            networkLogsURL: nil
        )
    }
}

// MARK: - API Client (Placeholder for actual implementation)

class QuashAPIClient {
    func uploadBugReport(
        reportData: [String: Any],
        screenshotURL: URL?,
        networkLogsURL: URL?,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        // In a real implementation, this would upload the bug report to the Quash backend
        // For now, just simulate a successful upload
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            completion(true, nil)
        }
    }
} 