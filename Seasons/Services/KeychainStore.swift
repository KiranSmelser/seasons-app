import Foundation
import Security

/// Thin wrapper around the iOS Keychain for storing small boolean values securely.
/// Uses kSecClassGenericPassword with the app bundle ID as the service name.
/// Items are stored with kSecAttrAccessibleWhenUnlockedThisDeviceOnly to prevent
/// iCloud Keychain backup and restrict access to this device only.
enum KeychainStore {
    private static let service = Bundle.main.bundleIdentifier ?? "com.kiransmelser.seasons"

    static func setBool(_ value: Bool, forKey key: String) {
        let data = Data([value ? 1 : 0])
        // Delete any existing item first so SecItemAdd always succeeds.
        delete(forKey: key)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func bool(forKey key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecReturnData: true as CFTypeRef,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              !data.isEmpty else { return false }
        return data[0] == 1
    }

    static func delete(forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Deletes all Keychain items whose account key starts with `prefix`.
    static func deleteAll(withPrefix prefix: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecReturnAttributes: true as CFTypeRef,
            kSecMatchLimit: kSecMatchLimitAll
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[CFString: Any]] else { return }

        for item in items {
            guard let account = item[kSecAttrAccount] as? String,
                  account.hasPrefix(prefix) else { continue }
            delete(forKey: account)
        }
    }
}
