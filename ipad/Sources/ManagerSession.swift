import Foundation
import Security

final class ManagerSession {
    private let service = "com.houseofpizza.commandcenter.ipad.session"
    private let account = "manager"
    private(set) var token: String?
    init() {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data {
            token = String(data: data, encoding: .utf8)
        }
    }
    private var baseQuery: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] }
    func save(_ value: String) throws {
        guard !value.isEmpty, value.count < 16384 else { throw SessionError.invalidToken }
        let attributes: [String: Any] = [kSecValueData as String: Data(value.utf8), kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(baseQuery.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw SessionError.keychain }
        token = value
    }
    func clear() { SecItemDelete(baseQuery as CFDictionary); token = nil }
    enum SessionError: LocalizedError {
        case invalidToken, keychain
        var errorDescription: String? { "The secure manager session could not be saved. Please sign in again." }
    }
}
