import Foundation
import Security

/// Minimal Keychain wrapper for small secrets (generic passwords) stored under a single service.
enum KeychainStore {
    // Scope items to this build's bundle id so a Debug ("…​.debug") and Release build keep
    // independent secrets and can run side by side.
    private static let service = Bundle.main.bundleIdentifier ?? "macos-heroboard.Heroboard"

    static func set(_ value: String?, for account: String) {
        guard let value, !value.isEmpty else {
            delete(account)
            return
        }

        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            if addStatus != errSecSuccess {
                Logging.default.log("Keychain add failed for \(account): \(addStatus)")
            }
        } else if status != errSecSuccess {
            Logging.default.log("Keychain update failed for \(account): \(status)")
        }
    }

    static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        guard
            SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data,
            let value = String(data: data, encoding: .utf8)
        else { return nil }

        return value
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
