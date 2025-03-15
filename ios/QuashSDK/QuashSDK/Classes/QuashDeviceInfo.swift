import UIKit
import SystemConfiguration
import SystemConfiguration.CaptiveNetwork
import SystemConfiguration.SCNetworkReachability

class QuashDeviceInfo {
    func collectDeviceInfo() -> [String: String] {
        var deviceInfo: [String: String] = [:]
        
        // Device model and identifiers
        deviceInfo["device_model"] = getDeviceModel()
        deviceInfo["device_name"] = UIDevice.current.name
        deviceInfo["system_name"] = UIDevice.current.systemName
        deviceInfo["system_version"] = UIDevice.current.systemVersion
        deviceInfo["device_identifier"] = UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
        
        // Screen dimensions
        let screen = UIScreen.main
        deviceInfo["screen_width"] = String(format: "%.0f", screen.bounds.width)
        deviceInfo["screen_height"] = String(format: "%.0f", screen.bounds.height)
        deviceInfo["screen_scale"] = String(format: "%.1f", screen.scale)
        deviceInfo["screen_native_scale"] = String(format: "%.1f", screen.nativeScale)
        
        // App info
        if let info = Bundle.main.infoDictionary {
            deviceInfo["app_version"] = info["CFBundleShortVersionString"] as? String ?? "Unknown"
            deviceInfo["app_build"] = info["CFBundleVersion"] as? String ?? "Unknown"
            deviceInfo["app_name"] = info["CFBundleName"] as? String ?? "Unknown"
            deviceInfo["app_bundle_id"] = Bundle.main.bundleIdentifier ?? "Unknown"
        }
        
        // Memory info
        let processInfo = ProcessInfo.processInfo
        deviceInfo["memory_total"] = String(format: "%.1f GB", Double(processInfo.physicalMemory) / 1_073_741_824)
        deviceInfo["processor_count"] = String(processInfo.processorCount)
        
        // Battery info
        UIDevice.current.isBatteryMonitoringEnabled = true
        deviceInfo["battery_level"] = String(format: "%.0f%%", UIDevice.current.batteryLevel * 100)
        deviceInfo["battery_state"] = batteryStateString(UIDevice.current.batteryState)
        
        // Network info
        deviceInfo["network_type"] = currentNetworkType()
        
        // Locale info
        let locale = Locale.current
        deviceInfo["locale_identifier"] = locale.identifier
        deviceInfo["locale_language"] = locale.languageCode ?? "Unknown"
        deviceInfo["locale_region"] = locale.regionCode ?? "Unknown"
        
        // Time zone
        let timezone = TimeZone.current
        deviceInfo["timezone"] = timezone.identifier
        deviceInfo["timezone_offset"] = String(timezone.secondsFromGMT()/3600)
        
        return deviceInfo
    }
    
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        // Map common device identifiers to human-readable device names
        switch identifier {
        case "iPhone13,1": return "iPhone 12 mini"
        case "iPhone13,2": return "iPhone 12"
        case "iPhone13,3": return "iPhone 12 Pro"
        case "iPhone13,4": return "iPhone 12 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4": return "iPad Pro 11-inch (1st gen)"
        case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8": return "iPad Pro 12.9-inch (3rd gen)"
        case "iPad13,1", "iPad13,2": return "iPad Air (4th gen)"
        case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7": return "iPad Pro 11-inch (3rd gen)"
        case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11": return "iPad Pro 12.9-inch (5th gen)"
        // Add more mappings as needed
        default: return identifier
        }
    }
    
    private func batteryStateString(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .charging: return "Charging"
        case .full: return "Full"
        case .unplugged: return "Unplugged"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
    
    private func currentNetworkType() -> String {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let reachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }) else {
            return "Unknown"
        }
        
        var flags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(reachability, &flags) {
            return "Unknown"
        }
        
        let isReachable = (flags.rawValue & UInt32(1 << 1)) != 0 // kSCNetworkFlagsReachable
        let needsConnection = (flags.rawValue & UInt32(1 << 2)) != 0 // kSCNetworkFlagsConnectionRequired
        
        let canConnectAutomatically = (flags.rawValue & UInt32(1 << 3)) != 0 || // kSCNetworkFlagsConnectionOnDemand
            (flags.rawValue & UInt32(1 << 4)) != 0 // kSCNetworkFlagsConnectionOnTraffic
        
        let canConnectWithoutUserInteraction = canConnectAutomatically &&
            (flags.rawValue & UInt32(1 << 5)) == 0 // kSCNetworkFlagsInterventionRequired
        
        if (isReachable && (!needsConnection || canConnectWithoutUserInteraction)) {
            // Check for WWAN connection (iOS only)
            if (flags.rawValue & UInt32(1 << 18)) != 0 { // kSCNetworkReachabilityFlagsIsWWAN
                return "Cellular"
            } else {
                return "WiFi"
            }
        } else {
            return "Not Connected"
        }
    }
} 