import SwiftUI
import QuashSDK

@main
struct ios_exampleApp: App {
    init() {
        Quash.initialize(
            applicationKey: "YOUR_APPLICATION_KEY",
            enableNetworkLogging: true
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .withQuash()
        }
    }
} 