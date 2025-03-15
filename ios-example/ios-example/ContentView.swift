import SwiftUI
import QuashSDK

struct ContentView: View {
    @State private var showingCustomDataAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HeaderSection()
                    FeaturesSection()
                    ActionButtons(showingCustomDataAlert: $showingCustomDataAlert)
                }
                .padding()
            }
            .navigationTitle("Quash iOS SDK")
            .alert("Add Custom Data", isPresented: $showingCustomDataAlert) {
                Button("Add") {
                    Quash.shared.addCustomData(key: "example_key", value: "example_value")
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will add example custom data to your bug reports.")
            }
        }
    }
}

struct HeaderSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Welcome to Quash iOS SDK")
                .font(.title)
                .fontWeight(.bold)
            
            Text("This example app demonstrates the key features of the Quash SDK.")
                .foregroundColor(.secondary)
        }
    }
}

struct FeaturesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Features")
                .font(.title2)
                .fontWeight(.bold)
            
            FeatureRow(title: "Bug Reporting", description: "Shake your device or tap the button below to report a bug")
            FeatureRow(title: "Session Recording", description: "Records user interactions leading up to a bug")
            FeatureRow(title: "Network Logging", description: "Automatically captures network requests and responses")
            FeatureRow(title: "Crash Reporting", description: "Automatically captures and reports app crashes")
        }
    }
}

struct ActionButtons: View {
    @Binding var showingCustomDataAlert: Bool
    
    var body: some View {
        VStack(spacing: 10) {
            Button {
                Quash.shared.reportBug()
            } label: {
                Text("Report a Bug")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            Button {
                showingCustomDataAlert = true
            } label: {
                Text("Add Custom Data")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button {
                fatalError("This is a simulated crash")
            } label: {
                Text("Simulate Crash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
}

struct FeatureRow: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ContentView()
} 