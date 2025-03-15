import SwiftUI
import UIKit

class QuashScreenshotService {
    static let shared = QuashScreenshotService()
    
    private init() {}
    
    func takeScreenshot() async -> UIImage? {
        await MainActor.run {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows
                .first(where: { $0.isKeyWindow }) else { return nil }
            
            UIGraphicsBeginImageContextWithOptions(window.bounds.size, false, window.screen.scale)
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return image
        }
    }
} 