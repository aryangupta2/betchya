import Foundation
import Security

enum UserIdentity {
    /// Stable anonymous id (Keychain; synchronizable when possible).
    static func currentUserId() -> String {
        if let existing = readKeychain(key: AppConstants.userIDKey) {
            return existing
        }
        let id = UUID().uuidString
        writeKeychain(key: AppConstants.userIDKey, value: id)
        return id
    }

    static func nickname(forGroup groupId: String) -> String? {
        let value = nicknames()[groupId]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value : nil
    }

    static func setNickname(_ nickname: String, forGroup groupId: String) {
        var map = nicknames()
        map[groupId] = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        saveNicknames(map)
    }

    /// Local group id for this chat until the backend owns groups (Step 3+).
    static func ensureGroupId() -> String {
        if let existing = defaults.string(forKey: AppConstants.groupIDKey), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        defaults.set(id, forKey: AppConstants.groupIDKey)
        return id
    }

    static func setGroupId(_ id: String) {
        defaults.set(id, forKey: AppConstants.groupIDKey)
    }

    // MARK: - Storage

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    private static func nicknames() -> [String: String] {
        guard
            let data = defaults.data(forKey: AppConstants.nicknamesKey),
            let map = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return map
    }

    private static func saveNicknames(_ map: [String: String]) {
        if let data = try? JSONEncoder().encode(map) {
            defaults.set(data, forKey: AppConstants.nicknamesKey)
        }
    }

    private static func readKeychain(key: String) -> String? {
        if let value = copyKeychain(key: key, useAccessGroup: true) {
            return value
        }
        return copyKeychain(key: key, useAccessGroup: false)
    }

    private static func copyKeychain(key: String, useAccessGroup: Bool) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        if useAccessGroup {
            query[kSecAttrAccessGroup as String] = AppConstants.appGroupID
        }
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    private static func writeKeychain(key: String, value: String) {
        let data = Data(value.utf8)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: true,
            kSecAttrAccessGroup as String: AppConstants.appGroupID
        ]
        SecItemDelete(query as CFDictionary)
        if SecItemAdd(query as CFDictionary, nil) != errSecSuccess {
            query.removeValue(forKey: kSecAttrAccessGroup as String)
            SecItemDelete(query as CFDictionary)
            SecItemAdd(query as CFDictionary, nil)
        }
    }
}
