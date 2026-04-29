import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    
    private let apiKeyAccount = "com.elianai.gemini-api-key"
    private let service = "ElianAI"
    
    private init() {}
    
    // MARK: - API Key
    
    var apiKey: String? {
        get { read(account: apiKeyAccount) }
        set {
            if let newValue {
                save(value: newValue, account: apiKeyAccount)
            } else {
                delete(account: apiKeyAccount)
            }
        }
    }
    
    var hasAPIKey: Bool {
        apiKey != nil && !(apiKey?.isEmpty ?? true)
    }
    
    // MARK: - Keychain Operations
    
    private func save(value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        // Delete existing item first
        delete(account: account)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
