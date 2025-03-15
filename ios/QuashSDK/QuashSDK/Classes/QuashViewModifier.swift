import SwiftUI

struct QuashViewModifier: ViewModifier {
    @StateObject private var quash = Quash.shared
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $quash.showingBugReporter) {
                QuashBugReportView(
                    screenshotURL: quash.currentScreenshotURL,
                    deviceInfo: quash.deviceInfo.collectDeviceInfo(),
                    customData: quash.customData,
                    networkLogsURL: quash.networkLogger.getLogFileURL()
                )
            }
            .sheet(isPresented: $quash.showingPermissions) {
                QuashPermissionView()
            }
    }
}

public extension View {
    func withQuash() -> some View {
        modifier(QuashViewModifier())
    }
} 