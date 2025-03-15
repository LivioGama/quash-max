import Foundation

class QuashNetworkLogger {
    private let maxLogEntries = 100
    private let logFileName = "quash_network_logs.json"
    private var networkLogs: [NetworkLog] = []
    private let logQueue = DispatchQueue(label: "com.quash.networkLoggerQueue")
    
    var alamofireMonitor: Any? {
        // This would be implemented for Alamofire integration
        // For now, it returns nil
        return nil
    }
}

// Moved outside of the class to be accessible to other classes
struct NetworkLog: Codable {
    let requestId: String
    let timestamp: Date
    let url: String
    let method: String
    let requestHeaders: [String: String]
    let requestBody: String?
    let responseStatusCode: Int?
    let responseHeaders: [String: String]?
    let responseBody: String?
    let duration: TimeInterval?
    let error: String?
    
    init(
        requestId: String = UUID().uuidString,
        timestamp: Date = Date(),
        url: String,
        method: String,
        requestHeaders: [String: String],
        requestBody: String?,
        responseStatusCode: Int? = nil,
        responseHeaders: [String: String]? = nil,
        responseBody: String? = nil,
        duration: TimeInterval? = nil,
        error: String? = nil
    ) {
        self.requestId = requestId
        self.timestamp = timestamp
        self.url = url
        self.method = method
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.responseStatusCode = responseStatusCode
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.duration = duration
        self.error = error
    }
}

extension QuashNetworkLogger {
    func startLogging() {
        URLProtocol.registerClass(QuashURLProtocol.self)
        
        // Register to receive notifications from QuashURLProtocol
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveNetworkLogNotification(_:)),
            name: Notification.Name("QuashNetworkLog"),
            object: nil
        )
    }
    
    func stopLogging() {
        URLProtocol.unregisterClass(QuashURLProtocol.self)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func didReceiveNetworkLogNotification(_ notification: Notification) {
        guard let networkLog = notification.object as? NetworkLog else { return }
        
        logQueue.async {
            self.networkLogs.append(networkLog)
            
            // Trim logs if we exceed the maximum
            if self.networkLogs.count > self.maxLogEntries {
                self.networkLogs.removeFirst(self.networkLogs.count - self.maxLogEntries)
            }
        }
    }
    
    func clearLogs() {
        logQueue.async {
            self.networkLogs.removeAll()
        }
    }
    
    func saveLogsToFile() {
        logQueue.async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(self.networkLogs)
                
                let fileURL = self.getLogFileURL()
                try data.write(to: fileURL)
                print("QuashSDK: Network logs saved to: \(fileURL.path)")
            } catch {
                print("QuashSDK: Failed to save network logs: \(error)")
            }
        }
    }
    
    func getLogFileURL() -> URL {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        return tempDirectory.appendingPathComponent(logFileName)
    }
    
    func getNetworkLogs() -> [NetworkLog] {
        var logs: [NetworkLog] = []
        
        logQueue.sync {
            logs = self.networkLogs
        }
        
        return logs
    }
}

class QuashURLProtocol: URLProtocol {
    static let QuashHandledKey = "QuashURLProtocolHandled"
    
    private var session: URLSession?
    private var sessionTask: URLSessionDataTask?
    private var requestStartTime: Date?
    
    private var requestData: Data?
    private var responseData: Data?
    private var response: HTTPURLResponse?
    private var error: Error?
    
    // MARK: - URLProtocol
    
    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url, url.scheme == "http" || url.scheme == "https" else {
            return false
        }
        
        // Skip requests that have already been handled
        if URLProtocol.property(forKey: QuashHandledKey, in: request) != nil {
            return false
        }
        
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let req = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else { return }
        
        // Mark this request as handled
        URLProtocol.setProperty(true, forKey: QuashURLProtocol.QuashHandledKey, in: req)
        
        // Record start time
        requestStartTime = Date()
        
        // Store request body for logging
        requestData = request.httpBody
        
        // Create a new URL session for this request
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        // Start the request
        sessionTask = session?.dataTask(with: req as URLRequest)
        sessionTask?.resume()
    }
    
    override func stopLoading() {
        sessionTask?.cancel()
        session?.invalidateAndCancel()
    }
    
    // MARK: - Helper Methods
    
    private func logNetworkTransaction() {
        // Calculate duration
        var duration: TimeInterval?
        if let startTime = requestStartTime {
            duration = Date().timeIntervalSince(startTime)
        }
        
        // Extract request info
        let url = request.url?.absoluteString ?? ""
        let method = request.httpMethod ?? "GET"
        
        // Extract request headers
        var requestHeaders: [String: String] = [:]
        if let headerFields = request.allHTTPHeaderFields {
            requestHeaders = headerFields
        }
        
        // Extract request body as String if available
        var requestBodyString: String?
        if let data = requestData {
            requestBodyString = String(data: data, encoding: .utf8)
        }
        
        // Extract response info
        let statusCode = response?.statusCode
        
        // Extract response headers
        var responseHeaders: [String: String]?
        if let headerFields = response?.allHeaderFields as? [String: String] {
            responseHeaders = headerFields
        }
        
        // Extract response body as String if available
        var responseBodyString: String?
        if let data = responseData {
            responseBodyString = String(data: data, encoding: .utf8)
        }
        
        // Extract error info
        var errorString: String?
        if let err = error {
            errorString = err.localizedDescription
        }
        
        // Create network log entry
        let networkLog = NetworkLog(
            url: url,
            method: method,
            requestHeaders: requestHeaders,
            requestBody: requestBodyString,
            responseStatusCode: statusCode,
            responseHeaders: responseHeaders,
            responseBody: responseBodyString,
            duration: duration,
            error: errorString
        )
        
        // Post notification with the log entry
        NotificationCenter.default.post(name: Notification.Name("QuashNetworkLog"), object: networkLog)
    }
}

// MARK: - URLSessionDataDelegate

extension QuashURLProtocol: URLSessionDelegate, URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.response = response as? HTTPURLResponse
        self.responseData = Data()
        
        // Forward the response to the client
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Accumulate response data
        responseData?.append(data)
        
        // Forward the data to the client
        client?.urlProtocol(self, didLoad: data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            self.error = error
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
        
        // Log the completed network transaction
        logNetworkTransaction()
    }
} 