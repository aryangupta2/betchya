import Foundation

/// Points at Cloudflare Workers (`wrangler dev` locally or `*.workers.dev` when deployed).
enum APIClient {
    static var baseURL: URL {
        URL(string: ProcessInfo.processInfo.environment["BETCHYA_API_URL"] ?? "http://127.0.0.1:8787")!
    }
}
