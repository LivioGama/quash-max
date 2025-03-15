import UIKit
import SwiftUI
import CoreMotion
import Firebase
import FirebaseCrashlytics

@MainActor
public class Quash: ObservableObject {
    // MARK: - Singleton
    public static let shared = Quash()
    
    // MARK: - Public Properties
    public var alamofireMonitor: Any? {
        networkLogger.alamofireMonitor
    }
    
    public enum ActivationGesture {
        case shake
        case threeFingerTap
    }
    
    public enum CaptureFrequency {
        case low
        case medium
        case high
        
        var interval: TimeInterval {
            switch self {
            case .low: return 2.0
            case .medium: return 1.0
            case .high: return 0.5
            }
        }
    }
    
    public enum ScreenshotQuality {
        case low
        case medium
        case high
        
        var compressionQuality: CGFloat {
            switch self {
            case .low: return 0.3
            case .medium: return 0.6
            case .high: return 0.9
            }
        }
    }
    
    @Published public var activationGesture: ActivationGesture = .shake {
        didSet {
            setupActivationGesture()
        }
    }
    
    @Published public var showingBugReporter = false
    @Published public var showingPermissions = false
    
    // MARK: - Private Properties
    private var apiKey: String?
    private var applicationKey: String?
    private let appPreferences = QuashAppPreferences()
    internal let deviceInfo = QuashDeviceInfoImpl()
    internal let networkLogger = QuashNetworkLogger()
    private let sessionRecorder = QuashSessionRecorderImpl()
    private let crashHandler = QuashCrashHandler()
    private let screenshotService = QuashScreenshotService.shared
    private var motionManager: CMMotionManager?
    private var firebaseConfigured = false
    private var lastShakeTime: TimeInterval = 0
    private let shakeThresholdTime: TimeInterval = 3.0
    internal var customData: [String: Any] = [:]
    internal var currentScreenshotURL: URL?
    
    // MARK: - Static Initialize Method
    public static func initialize(
        applicationKey: String,
        enableNetworkLogging: Bool = true,
        sessionLength: Int = 40,
        useExistingFirebase: Bool = false
    ) {
        Task { @MainActor in
            await shared.initialize(
                applicationKey: applicationKey,
                enableNetworkLogging: enableNetworkLogging,
                sessionLength: sessionLength,
                useExistingFirebase: useExistingFirebase
            )
        }
    }
    
    // MARK: - Initialization
    private init() {}
    
    private func initialize(
        applicationKey: String,
        enableNetworkLogging: Bool,
        sessionLength: Int,
        useExistingFirebase: Bool
    ) async {
        print("QuashSDK: Initializing")
        self.applicationKey = applicationKey
        
        // Save preferences
        appPreferences.setSessionDuration(sessionLength)
        
        // Initialize network logging if needed
        if enableNetworkLogging {
            networkLogger.startLogging()
        }
        
        // Initialize session recorder
        sessionRecorder.initialize(
            quality: ScreenshotQuality.medium,
            frequency: CaptureFrequency.medium,
            sessionLength: sessionLength
        )
        
        // Initialize Firebase for crash reporting
        if !useExistingFirebase && !firebaseConfigured {
            configureFirebase()
        }
        
        // Set up activation gesture
        setupActivationGesture()
        
        // Register crash handler
        crashHandler.register()
        
        // Request permissions if needed
        await Task.sleep(2_000_000_000) // 2 seconds
        showingPermissions = true
        
        print("QuashSDK: Initialization completed")
    }
    
    // MARK: - Public Methods
    
    public func configure(
        screenshotQuality: ScreenshotQuality,
        captureFrequency: CaptureFrequency,
        sessionLength: Int
    ) {
        appPreferences.setSessionDuration(sessionLength)
        sessionRecorder.updateSettings(
            quality: screenshotQuality,
            frequency: captureFrequency,
            sessionLength: sessionLength
        )
    }
    
    public func addCustomData(key: String, value: Any) {
        customData[key] = value
    }
    
    public func clearCustomData() {
        customData.removeAll()
    }
    
    public func clearNetworkLogs() {
        networkLogger.clearLogs()
    }
    
    public func reportBug() {
        Task { @MainActor in
            await captureAndShowReporter()
        }
    }
    
    public func showBugReporter() {
        Task { @MainActor in
            await captureAndShowReporter()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupActivationGesture() {
        switch activationGesture {
        case .shake:
            setupShakeDetection()
        case .threeFingerTap:
            setupThreeFingerTapGesture()
        }
    }
    
    private func setupShakeDetection() {
        if motionManager == nil {
            motionManager = CMMotionManager()
        }
        
        guard let motionManager = motionManager, motionManager.isAccelerometerAvailable else {
            print("QuashSDK: Accelerometer not available")
            return
        }
        
        motionManager.accelerometerUpdateInterval = 0.1
        
        let queue = OperationQueue()
        motionManager.startAccelerometerUpdates(to: queue) { [weak self] (data, error) in
            guard let self = self, let data = data else { return }
            
            let threshold = 2.0
            let current = sqrt(pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2) + pow(data.acceleration.z, 2))
            
            if current > threshold {
                let currentTime = Date().timeIntervalSince1970
                if currentTime - self.lastShakeTime > self.shakeThresholdTime {
                    self.lastShakeTime = currentTime
                    Task { @MainActor in
                        await self.captureAndShowReporter()
                    }
                }
            }
        }
    }
    
    private func setupThreeFingerTapGesture() {
        // Create a new tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleThreeFingerTap(_:)))
        tapGesture.numberOfTouchesRequired = 3
        
        // Add it to the main window
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows
            .first(where: { $0.isKeyWindow }) {
            window.addGestureRecognizer(tapGesture)
        }
    }
    
    @objc private func handleThreeFingerTap(_ gesture: UITapGestureRecognizer) {
        Task { @MainActor in
            await captureAndShowReporter()
        }
    }
    
    private func captureAndShowReporter() async {
        // Capture the current state
        if let screenshot = await screenshotService.takeScreenshot() {
            // Save screenshot to file
            if let imageURL = await saveScreenshotToFile(screenshot) {
                // Save network logs
                networkLogger.saveLogsToFile()
                
                // Store screenshot URL and show bug reporter
                currentScreenshotURL = imageURL
                showingBugReporter = true
            }
        }
    }
    
    private func saveScreenshotToFile(_ image: UIImage) async -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        
        let filename = "screenshot_\(Int(Date().timeIntervalSince1970)).jpg"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("QuashSDK: Failed to save screenshot: \(error)")
            return nil
        }
    }
    
    private func configureFirebase() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        firebaseConfigured = true
    }
}

// MARK: - Supporting Classes

class QuashAppPreferences {
    private let defaults = UserDefaults.standard
    private let sessionDurationKey = "com.quash.sessionDuration"
    
    func setSessionDuration(_ duration: Int) {
        defaults.set(duration, forKey: sessionDurationKey)
    }
    
    func getSessionDuration() -> Int {
        defaults.integer(forKey: sessionDurationKey)
    }
}

internal struct QuashDeviceInfoImpl {
    internal func collectDeviceInfo() -> [String: String] {
        var deviceInfo: [String: String] = [:]
        
        // Device model
        let device = UIDevice.current
        deviceInfo["device_model"] = device.model
        deviceInfo["device_name"] = device.name
        deviceInfo["system_name"] = device.systemName
        deviceInfo["system_version"] = device.systemVersion
        
        // Screen dimensions
        let screen = UIScreen.main
        deviceInfo["screen_width"] = String(format: "%.0f", screen.bounds.width)
        deviceInfo["screen_height"] = String(format: "%.0f", screen.bounds.height)
        deviceInfo["screen_scale"] = String(format: "%.1f", screen.scale)
        
        // App info
        if let info = Bundle.main.infoDictionary {
            deviceInfo["app_version"] = info["CFBundleShortVersionString"] as? String ?? "Unknown"
            deviceInfo["app_build"] = info["CFBundleVersion"] as? String ?? "Unknown"
            deviceInfo["app_name"] = info["CFBundleName"] as? String ?? "Unknown"
        }
        
        // Memory info
        let processInfo = ProcessInfo.processInfo
        deviceInfo["memory_total"] = String(format: "%.1f GB", Double(processInfo.physicalMemory) / 1_073_741_824)
        
        return deviceInfo
    }
}

class QuashCrashHandler {
    private var previousCrashHandler: (@convention(c) (NSException) -> Void)?
    private static var sharedInstance: QuashCrashHandler?
    
    init() {
        QuashCrashHandler.sharedInstance = self
    }
    
    func register() {
        previousCrashHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(QuashCrashHandler.handleException)
    }
    
    @objc static let handleException: @convention(c) (NSException) -> Void = { exception in
        QuashCrashHandler.sharedInstance?.handleExceptionInternal(exception)
        
        // Call previous handler if exists
        if let previousHandler = QuashCrashHandler.sharedInstance?.previousCrashHandler {
            previousHandler(exception)
        }
    }
    
    private func handleExceptionInternal(_ exception: NSException) {
        // Log the exception
        let reason = exception.reason ?? "No reason provided"
        let name = exception.name.rawValue
        let callStack = exception.callStackSymbols.joined(separator: "\n")
        
        print("QuashSDK: Uncaught exception - \(name): \(reason)")
        print("QuashSDK: Call stack: \(callStack)")
        
        // Save the crash log
        saveCrashLog(name: name, reason: reason, callStack: callStack)
    }
    
    private func saveCrashLog(name: String, reason: String, callStack: String) {
        let crashInfo = [
            "name": name,
            "reason": reason,
            "callStack": callStack,
            "timestamp": String(Date().timeIntervalSince1970)
        ]
        
        // Convert to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: crashInfo) else {
            return
        }
        
        // Save to a file
        let filename = "crash_\(Int(Date().timeIntervalSince1970)).json"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try jsonData.write(to: fileURL)
        } catch {
            print("QuashSDK: Failed to save crash log: \(error)")
        }
    }
}

private class QuashSessionRecorderImpl {
    private var timer: Timer?
    private var quality: Quash.ScreenshotQuality = .medium
    private var frequency: Quash.CaptureFrequency = .medium
    private var sessionLength: Int = 40
    private var screenshots: [UIImage] = []
    private var isRecording = false
    
    func initialize(
        quality: Quash.ScreenshotQuality,
        frequency: Quash.CaptureFrequency,
        sessionLength: Int
    ) {
        self.quality = quality
        self.frequency = frequency
        self.sessionLength = sessionLength
        
        // Start recording
        startRecording()
    }
    
    func updateSettings(
        quality: Quash.ScreenshotQuality,
        frequency: Quash.CaptureFrequency,
        sessionLength: Int
    ) {
        self.quality = quality
        self.frequency = frequency
        self.sessionLength = sessionLength
        
        // Restart recording with new settings
        if isRecording {
            stopRecording()
            startRecording()
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        isRecording = true
        
        // Calculate buffer size
        let bufferSize = Int(Double(sessionLength) / frequency.interval)
        
        // Start a timer to capture screenshots
        timer = Timer.scheduledTimer(withTimeInterval: frequency.interval, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording else { return }
            
            if let screenshot = self.takeScreenshot() {
                // Add to circular buffer
                self.screenshots.append(screenshot)
                
                // Keep buffer size limited
                if self.screenshots.count > bufferSize {
                    self.screenshots.removeFirst()
                }
            }
        }
    }
    
    func pauseRecording() {
        isRecording = false
        timer?.invalidate()
        timer = nil
    }
    
    func resumeRecording() {
        startRecording()
    }
    
    func stopRecording() {
        isRecording = false
        timer?.invalidate()
        timer = nil
        screenshots.removeAll()
    }
    
    func captureScreenshot() -> UIImage? {
        return takeScreenshot()
    }
    
    private func takeScreenshot() -> UIImage? {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        
        UIGraphicsBeginImageContextWithOptions(window.bounds.size, false, 0)
        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        let screenshot = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return screenshot
    }
} 