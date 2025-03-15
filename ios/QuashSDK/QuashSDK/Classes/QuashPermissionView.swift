import SwiftUI
import Photos

struct QuashPermissionView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - State
    
    @State private var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // Header
                Text("Quash Permissions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                // Description
                Text("Quash needs permission to save screenshots and access photos for bug reporting.")
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                // Photo library permission button
                Button(action: requestPhotoAccess) {
                    HStack {
                        Image(systemName: getPhotoLibraryIcon())
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                        
                        VStack(alignment: .leading) {
                            Text("Photo Library")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Access to save and upload screenshots")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(getPhotoLibraryButtonColor())
                    .cornerRadius(10)
                }
                .disabled(photoLibraryStatus == .authorized || photoLibraryStatus == .limited)
                .padding(.horizontal)
                
                // Continue button
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(continueButtonEnabled ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!continueButtonEnabled)
                .padding(.horizontal)
                .padding(.top, 12)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: 350)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
            )
            .padding()
        }
        .onAppear {
            checkCurrentPermissions()
        }
    }
    
    // MARK: - Computed Properties
    
    private var continueButtonEnabled: Bool {
        photoLibraryStatus == .authorized || photoLibraryStatus == .limited
    }
    
    private func getPhotoLibraryButtonColor() -> Color {
        switch photoLibraryStatus {
        case .authorized, .limited:
            return Color.green
        case .denied, .restricted:
            return Color.red
        default:
            return Color.blue
        }
    }
    
    private func getPhotoLibraryIcon() -> String {
        switch photoLibraryStatus {
        case .authorized, .limited:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        default:
            return "photo.on.rectangle"
        }
    }
    
    // MARK: - Methods
    
    private func checkCurrentPermissions() {
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus()
    }
    
    private func requestPhotoAccess() {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                self.photoLibraryStatus = status
            }
        }
    }
}

struct QuashPermissionView_Previews: PreviewProvider {
    static var previews: some View {
        QuashPermissionView()
    }
} 