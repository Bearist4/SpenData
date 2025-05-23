import Foundation
import Security
import CloudKit

class SecureStorageService {
    static let shared = SecureStorageService()
    private let encryptionService: EncryptionService
    
    private init() {
        self.encryptionService = EncryptionService.shared
    }
    
    // MARK: - Keychain Operations
    
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
    
    // MARK: - iCloud Operations
    
    func saveToiCloud(key: String, data: Data) async throws {
        let container = CKContainer.default()
        let privateDatabase = container.privateCloudDatabase
        
        let record = CKRecord(recordType: "SecureData")
        record.setValue(data, forKey: key)
        
        // Debug: Print CloudKit record details
        print("📦 CloudKit Record Details:")
        print("Record Type: \(record.recordType)")
        print("Record ID: \(record.recordID.recordName)")
        print("Key: \(key)")
        print("Data Size: \(data.count) bytes")
        
        try await privateDatabase.save(record)
        print("✅ Successfully saved to iCloud")
    }
    
    func loadFromiCloud(key: String) async throws -> Data {
        let container = CKContainer.default()
        let privateDatabase = container.privateCloudDatabase
        
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "SecureData", predicate: predicate)
        
        print("🔍 Loading from iCloud with key: \(key)")
        
        let (results, _) = try await privateDatabase.records(matching: query)
        guard let record = try results.first?.1.get() else {
            print("❌ No record found in iCloud")
            throw CloudKitError.recordNotFound
        }
        
        guard let data = record.value(forKey: key) as? Data else {
            print("❌ Invalid data format in iCloud record")
            throw CloudKitError.invalidData
        }
        
        print("✅ Successfully loaded from iCloud")
        return data
    }
    
    func deleteFromiCloud(key: String) async throws {
        let container = CKContainer.default()
        let privateDatabase = container.privateCloudDatabase
        
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "SecureData", predicate: predicate)
        
        print("🗑️ Deleting from iCloud with key: \(key)")
        
        let (results, _) = try await privateDatabase.records(matching: query)
        if let recordID = try results.first?.0 {
            try await privateDatabase.deleteRecord(withID: recordID)
            print("✅ Successfully deleted from iCloud")
        } else {
            print("⚠️ No record found to delete")
        }
    }
    
    func syncWithiCloud() async throws {
        let container = CKContainer.default()
        let privateDatabase = container.privateCloudDatabase
        
        // Set up subscription for real-time updates
        let subscription = CKQuerySubscription(
            recordType: "SecureData",
            predicate: NSPredicate(value: true),
            subscriptionID: "secure-data-changes",
            options: [.firesOnRecordCreation, .firesOnRecordDeletion, .firesOnRecordUpdate]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        try await privateDatabase.save(subscription)
    }
} 