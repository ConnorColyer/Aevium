import Foundation
import Security

enum AeviumAPIKeyStore {
    static let didChangeNotification = Notification.Name("AeviumAPIKeyStoreDidChange")

    private static let legacyFinnhubDefaultsKey = "FinnhubAPIKey"
    private static let finnhubAccount = "finnhub.api.key"

    static func finnhubAPIKey() -> String? {
        if let key = try? keychainValue(account: finnhubAccount), !key.isEmpty {
            return key
        }

        guard let legacyKey = UserDefaults.standard
            .string(forKey: legacyFinnhubDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !legacyKey.isEmpty
        else {
            return nil
        }

        if (try? setKeychainValue(legacyKey, account: finnhubAccount)) != nil {
            UserDefaults.standard.removeObject(forKey: legacyFinnhubDefaultsKey)
        }

        return legacyKey
    }

    static func setFinnhubAPIKey(_ rawKey: String) throws {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if key.isEmpty {
            try deleteKeychainValue(account: finnhubAccount)
        } else {
            try setKeychainValue(key, account: finnhubAccount)
        }

        UserDefaults.standard.removeObject(forKey: legacyFinnhubDefaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func hasFinnhubAPIKey() -> Bool {
        finnhubAPIKey()?.isEmpty == false
    }

    private static var service: String {
        Bundle.main.bundleIdentifier ?? "com.aevium.desktop"
    }

    private static func keychainQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
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

    private static func setKeychainValue(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query = keychainQuery(account: account)
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw KeychainError(status: updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError(status: addStatus)
        }
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
