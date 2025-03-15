import UIKit

class QuashSessionRecorder {
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var quality: Quash.ScreenshotQuality = .medium
    private var frequency: Quash.CaptureFrequency = .medium
    private var sessionLength: Int = 40
    private var screenshots: [Screenshot] = []
    private var isRecording = false
    private let storageQueue = DispatchQueue(label: "com.quash.sessionRecorderQueue")
    
    // MARK: - Models
    
    struct Screenshot {
        let image: UIImage
        let timestamp: Date
        let memoryUsage: UInt64?
        let cpuUsage: Double?
        
        var jpegData: Data? {
            return image.jpegData(compressionQuality: 0.7)
        }
    }
    
    // MARK: - Public Methods
    
    func initialize(
        quality: Quash.ScreenshotQuality,
        frequency: Quash.CaptureFrequency,
        sessionLength: Int
    ) {
        self.quality = quality
        self.frequency = frequency
        self.sessionLength = sessionLength
        
        startRecording()
    }
    
    func updateSettings(
        quality: Quash.ScreenshotQuality,
        frequency: Quash.CaptureFrequency,
        sessionLength: Int
    ) {
        storageQueue.async {
            self.quality = quality
            self.frequency = frequency
            self.sessionLength = sessionLength
            
            // Restart recording with new settings
            if self.isRecording {
                self.stopRecording()
                self.startRecording()
            }
        }
    }
    
    func startRecording() {
        storageQueue.async {
            guard !self.isRecording else { return }
            
            self.isRecording = true
            
            // Calculate buffer size
            let bufferSize = Int(Double(self.sessionLength) / self.frequency.interval)
            
            // Start a timer to capture screenshots
            DispatchQueue.main.async {
                self.timer = Timer.scheduledTimer(withTimeInterval: self.frequency.interval, repeats: true) { [weak self] _ in
                    self?.captureScreenshotForRecording()
                }
            }
        }
    }
    
    func pauseRecording() {
        storageQueue.async {
            self.isRecording = false
            
            DispatchQueue.main.async {
                self.timer?.invalidate()
                self.timer = nil
            }
        }
    }
    
    func resumeRecording() {
        startRecording()
    }
    
    func stopRecording() {
        storageQueue.async {
            self.isRecording = false
            
            DispatchQueue.main.async {
                self.timer?.invalidate()
                self.timer = nil
            }
            
            // Clear the saved screenshots
            self.screenshots.removeAll()
        }
    }
    
    func captureScreenshot() -> UIImage? {
        return takeScreenshot()
    }
    
    func getAllScreenshots() -> [Screenshot] {
        var result: [Screenshot] = []
        
        storageQueue.sync {
            result = self.screenshots
        }
        
        return result
    }
    
    func saveSessionToFile() -> URL? {
        var fileURL: URL?
        
        storageQueue.sync {
            do {
                // Create a temporary directory to store the screenshots
                let tempDirectory = FileManager.default.temporaryDirectory
                let sessionDirectory = tempDirectory.appendingPathComponent("quash_session_\(Int(Date().timeIntervalSince1970))")
                
                try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
                
                // Save each screenshot
                for (index, screenshot) in self.screenshots.enumerated() {
                    if let data = screenshot.jpegData {
                        let fileURL = sessionDirectory.appendingPathComponent("frame_\(index).jpg")
                        try data.write(to: fileURL)
                    }
                }
                
                // Create a metadata file
                let metadata: [String: Any] = [
                    "frames": self.screenshots.count,
                    "duration": self.sessionLength,
                    "frequency": self.frequency.interval,
                    "quality": self.quality.compressionQuality,
                    "timestamp": Date().timeIntervalSince1970
                ]
                
                if let metadataData = try? JSONSerialization.data(withJSONObject: metadata) {
                    let metadataURL = sessionDirectory.appendingPathComponent("metadata.json")
                    try metadataData.write(to: metadataURL)
                }
                
                // Create a zip archive
                let zipURL = tempDirectory.appendingPathComponent("quash_session_\(Int(Date().timeIntervalSince1970)).zip")
                
                // Zip logic would go here - in a real implementation we'd use a library like ZIPFoundation
                // For now, just return the session directory
                fileURL = sessionDirectory
            } catch {
                print("QuashSDK: Failed to save session: \(error)")
            }
        }
        
        return fileURL
    }
    
    // MARK: - Private Methods
    
    private func captureScreenshotForRecording() {
        guard isRecording else { return }
        
        if let image = takeScreenshot() {
            let screenshot = Screenshot(
                image: image,
                timestamp: Date(),
                memoryUsage: getMemoryUsage(),
                cpuUsage: getCPUUsage()
            )
            
            storageQueue.async {
                // Add to circular buffer
                self.screenshots.append(screenshot)
                
                // Keep buffer size limited
                let bufferSize = Int(Double(self.sessionLength) / self.frequency.interval)
                if self.screenshots.count > bufferSize {
                    self.screenshots.removeFirst()
                }
            }
        }
    }
    
    private func takeScreenshot() -> UIImage? {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        
        // Begin image context
        UIGraphicsBeginImageContextWithOptions(window.bounds.size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        // Draw window hierarchy
        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        
        // Get image and end context
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    private func getMemoryUsage() -> UInt64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? info.resident_size : nil
    }
    
    private func getCPUUsage() -> Double? {
        var totalUsageOfCPU: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        
        let threadsResult = task_threads(mach_task_self_, &threadsList, &threadsCount)
        
        if threadsResult == KERN_SUCCESS, let threadsList = threadsList {
            for index in 0..<threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                let threadInfoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }
                
                if threadInfoResult == KERN_SUCCESS {
                    let threadBasicInfo = threadInfo
                    
                    if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                        totalUsageOfCPU = (totalUsageOfCPU + (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0))
                    }
                }
            }
            
            // Free the memory
            vm_deallocate(mach_task_self_, vm_address_t(Int(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        }
        
        return totalUsageOfCPU
    }
} 