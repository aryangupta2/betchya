import Foundation

/// Stub for Step 3+. Identity/nickname work offline until the backend exists.
enum APIClient {
    static var baseURL: URL {
        URL(string: ProcessInfo.processInfo.environment["BETCHYA_API_URL"] ?? "http://127.0.0.1:8787")!
    }
}
