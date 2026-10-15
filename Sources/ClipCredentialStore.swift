// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import Security

struct ClipLoginSecret {
    let userID: String
    let password: String
}

// Tests inject an in-memory store; they never read the production keychain.
struct ClipLoginStorage {
    var loadSecret: (String?) -> ClipLoginSecret?
    var saveAccount: (CloudClipAccount) -> Bool
    var saveSecret: (ClipLoginSecret) -> Bool
    var forget: () -> Void
    func persist(account: CloudClipAccount, password: String, remember: Bool) -> Bool {
        if !remember { forget(); return true }
        guard saveAccount(account), saveSecret(ClipLoginSecret(userID: account.userID, password: password)) else {
            forget(); return false
        }
        return true
    }
    static var keychain: Self {
        Self(loadSecret: ClipCredentialStore.loadSecret, saveAccount: ClipCredentialStore.saveCloud,
             saveSecret: ClipCredentialStore.saveSecret, forget: ClipCredentialStore.forgetCloud)
    }
}

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
    // Password is separate, this-device-only and only saved after successful
    // login with the visible remember-password checkbox enabled.
    private static var passwordQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "io.github.defenceforce1.wiznoteplus.clipper.cloud.password",
         kSecAttrAccount as String: "official-account"]
    }
    static func loadSecret(userID: String?) -> ClipLoginSecret? {
        var request = passwordQuery; request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess, let bytes = item as? Data,
              let value = try? JSONSerialization.jsonObject(with: bytes) as? [String: String],
              let user = value["userID"], let password = value["password"], !user.isEmpty, !password.isEmpty,
              userID == nil || userID == user else { return nil }
        return ClipLoginSecret(userID: user, password: password)
    }
    static func saveSecret(_ secret: ClipLoginSecret) -> Bool {
        guard !secret.userID.isEmpty, !secret.password.isEmpty,
              let bytes = try? JSONSerialization.data(withJSONObject: ["userID": secret.userID, "password": secret.password]) else { return false }
        let attributes: [String: Any] = [kSecValueData as String: bytes,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false]
        let status = SecItemUpdate(passwordQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return true }; if status != errSecItemNotFound { return false }
        return SecItemAdd(passwordQuery.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess
    }
    static func saveCloud(_ account: CloudClipAccount) -> Bool {
        guard let bytes = try? JSONSerialization.data(withJSONObject: account.dictionary) else { return false }
        let status = SecItemUpdate(cloudQuery as CFDictionary, [kSecValueData as String: bytes] as CFDictionary)
        if status == errSecSuccess { return true }; if status != errSecItemNotFound { return false }
        var request = cloudQuery; request[kSecValueData as String] = bytes
        request[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        return SecItemAdd(request as CFDictionary, nil) == errSecSuccess
    }
    static func forgetCloud() {
        SecItemDelete(cloudQuery as CFDictionary); SecItemDelete(passwordQuery as CFDictionary)
    }
}

// At most one reauthentication before a folder GET. Never retries a clip POST.
final class CloudClipSession {
    private let client: CloudClipClient
    private let storage: ClipLoginStorage
    init(client: CloudClipClient, storage: ClipLoginStorage) { self.client = client; self.storage = storage }
    func folders(account: CloudClipAccount, completion: @escaping (Result<(CloudClipAccount, [String]), Error>) -> Void) {
        client.folders(account: account) { result in
            switch result {
            case .success(let folders): completion(.success((account, folders)))
            case .failure(let error):
                guard CloudClipAPIError.requiresLogin(error), let secret = self.storage.loadSecret(account.userID),
                      secret.userID == account.userID else { completion(.failure(error)); return }
                self.client.login(userID: secret.userID, password: secret.password) { result in
                    switch result {
                    case .failure(let error): completion(.failure(error))
                    case .success(let renewed):
                        guard renewed.userID == account.userID, renewed.userGuid == account.userGuid,
                              renewed.kbGuid == account.kbGuid else {
                            completion(.failure(ClipperError.message("重新登录返回的账号不一致，请手动登录。"))); return
                        }
                        guard self.storage.saveAccount(renewed) else {
                            completion(.failure(ClipperError.message("无法更新钥匙串中的登录状态，请重新登录。"))); return
                        }
                        self.client.folders(account: renewed) { result in
                            completion(result.map { (renewed, $0) })
                        }
                    }
                }
            }
        }
    }
}
