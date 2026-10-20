import Foundation

enum AppConstants {
    static let appGroupID = "group.com.aryangupta.Betchya"
    static let userIDKey = "betchya.userId"
    static let nicknamesKey = "betchya.nicknamesByGroup"
    static let groupIDKey = "betchya.currentGroupId"
    /// Override with env `BETCHYA_API_URL` or change after `wrangler deploy`.
    static let apiBaseURL = URL(string: "https://betchya-api.betchya.workers.dev")!
    /// Deep link host embedded in MSMessage URLs (path carries query ids).
    static let messageURLBase = URL(string: "https://betchya.app/m")!
}
