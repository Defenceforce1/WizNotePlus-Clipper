// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import Security

enum ClipCredentialStore {
    private static var cloudQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "io.github.defenceforce1.wiznoteplus.clipper.cloud",
         kSecAttrAccount as String: "official-account"]
    }
    static func loadCloud() -> CloudClipAccount? {
        var request = cloudQuery; request[kSecReturnData as String] = true; request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess, let bytes = item as? Data,
              let dictionary = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { return nil }
        return try? CloudClipAccount(dictionary)
    }
    // Call only after the user explicitly selects 'remember login'. Never store password.
    static func saveCloud(_ account: CloudClipAccount) -> Bool {
        guard let bytes = try? JSONSerialization.data(withJSONObject: account.dictionary) else { return false }
        let status = SecItemUpdate(cloudQuery as CFDictionary, [kSecValueData as String: bytes] as CFDictionary)
        if status == errSecSuccess { return true }; if status != errSecItemNotFound { return false }
        var request = cloudQuery; request[kSecValueData as String] = bytes
        request[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        return SecItemAdd(request as CFDictionary, nil) == errSecSuccess
    }
    static func forgetCloud() { SecItemDelete(cloudQuery as CFDictionary) }
}
