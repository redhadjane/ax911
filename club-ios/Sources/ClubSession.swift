import Foundation
import Security

final class ClubSession {
    private let service = "com.houseofpizza.hopclub.ios.session"
    private let account = "customer"
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
    func pending(_ owner:String)->J? {
        var query=baseQuery;query[kSecAttrAccount as String]="pending-"+owner;query[kSecReturnData as String]=true;query[kSecMatchLimit as String]=kSecMatchLimitOne
        var result:CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary,&result) == errSecSuccess,let data=result as? Data else{return nil}
        return try? JSONDecoder().decode(J.self,from:data)
    }
    func savePending(_ value:J?,owner:String) throws {
        var query=baseQuery;query[kSecAttrAccount as String]="pending-"+owner
        guard let value else {SecItemDelete(query as CFDictionary);return}
        let data=try JSONEncoder().encode(value)
        let values:[String:Any]=[kSecValueData as String:data,kSecAttrAccessible as String:kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status=SecItemUpdate(query as CFDictionary,values as CFDictionary)
        if status == errSecItemNotFound {status=SecItemAdd(query.merging(values){_,n in n} as CFDictionary,nil)}
        guard status == errSecSuccess else{throw SessionError.keychain}
    }
    enum SessionError: LocalizedError {
        case invalidToken, keychain
        var errorDescription: String? { "The secure customer session could not be saved. Please sign in again." }
    }
}
