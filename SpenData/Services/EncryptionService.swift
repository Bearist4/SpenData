import Foundation
import CryptoKit

class EncryptionService {
    static let shared = EncryptionService()
    private let keychainService = "Bearista.SpenData"
    
    private init() {}
    
    // MARK: - Encryption Methods
    
    func encrypt(_ data: Data) throws -> EncryptedData {
        let key = try getOrCreateKey()
        let nonce = try AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        
        return EncryptedData(
            ciphertext: sealedBox.ciphertext,
            nonce: nonce,
            tag: sealedBox.tag
        )
    }
    
    func decrypt(_ encryptedData: EncryptedData) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(
            nonce: encryptedData.nonceValue,
            ciphertext: encryptedData.ciphertext,
            tag: encryptedData.tag
        )
        
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    // MARK: - Key Management
    
    private func getOrCreateKey() throws -> SymmetricKey {
        let keychain = KeychainService.shared
        
        do {
            let keyData = try keychain.loadFromKeychain(key: "encryptionKey")
            return SymmetricKey(data: keyData)
        } catch {
            // Key doesn't exist, create a new one
            let key = SymmetricKey(size: .bits256)
            let keyData = key.withUnsafeBytes { Data($0) }
            try keychain.saveToKeychain(key: "encryptionKey", data: keyData)
            return key
        }
    }
}

// MARK: - Supporting Types

struct EncryptedData: Codable {
    let ciphertext: Data
    let nonce: Data
    let tag: Data
    
    init(ciphertext: Data, nonce: AES.GCM.Nonce, tag: Data) {
        self.ciphertext = ciphertext
        self.nonce = nonce.withUnsafeBytes { Data($0) }
        self.tag = tag
    }
    
    var nonceValue: AES.GCM.Nonce {
        try! AES.GCM.Nonce(data: nonce)
    }
}

// MARK: - Keychain Service

class KeychainService {
    static let shared = KeychainService()
    
    private init() {}
    
    func saveToKeychain(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        // First try to delete any existing data
        SecItemDelete(query as CFDictionary)
        
        // Then add the new data
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }
    
    func loadFromKeychain(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw KeychainError.loadFailed(status: status)
        }
        
        return data
    }
    
    func deleteFromKeychain(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }
} 