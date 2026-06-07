import Foundation
import Security

enum AeviumAPIKeyStore {
    static let didChangeNotification = Notification.Name("AeviumAPIKeyStoreDidChange")

    private static let finnhubDefaultsKey = "FinnhubAPIKey"
    private static let legacyKeychainAccount = "finnhub.api.key"

    static func finnhubAPIKey() -> String? {
        if let localKey = UserDefaults.standard
            .string(forKey: finnhubDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !localKey.isEmpty {
            return localKey
        }

        guard let migratedKey = try? keychainValue(account: legacyKeychainAccount), !migratedKey.isEmpty else {
            return nil
        }

        UserDefaults.standard.set(migratedKey, forKey: finnhubDefaultsKey)
        _ = try? deleteKeychainValue(account: legacyKeychainAccount)
        return migratedKey
    }

    static func setFinnhubAPIKey(_ rawKey: String) throws {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if key.isEmpty {
            UserDefaults.standard.removeObject(forKey: finnhubDefaultsKey)
        } else {
            UserDefaults.standard.set(key, forKey: finnhubDefaultsKey)
        }

        _ = try? deleteKeychainValue(account: legacyKeychainAccount)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func hasFinnhubAPIKey() -> Bool {
        finnhubAPIKey()?.isEmpty == false
    }

    private static var legacyKeychainService: String {
        Bundle.main.bundleIdentifier ?? "com.aevium.desktop"
    }

    private static func keychainQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyKeychainService,
            kSecAttrAccount as String: account
        ]
    }

    private static func keychainValue(account: String) throws -> String? {
        var query = keychainQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }

        guard let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private static func deleteKeychainValue(account: String) throws {
        let status = SecItemDelete(keychainQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}

struct KeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return message
        }

        return "Keychain error \(status)"
    }
}
