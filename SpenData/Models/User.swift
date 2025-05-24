import Foundation
import SwiftData
import CloudKit
import UIKit

@Model
final class User {
    var id: String?
    var email: String?
    var name: String?
    var createdAt: Date = Date()
    var lastLoginDate: Date = Date()
    var deviceIdentifier: String = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    
    // Relationships
    @Relationship(deleteRule: .cascade) var bills: [Bill]?
    @Relationship(deleteRule: .cascade) var transactions: [Transaction]?
    @Relationship(deleteRule: .cascade) var billBudgets: [BillBudget]?
    @Relationship(deleteRule: .cascade) var transactionBudgets: [TransactionBudget]?
    
    init(id: String = UUID().uuidString,
         email: String,
         name: String) {
        self.id = id
        self.email = email
        self.name = name
        self.bills = []
        self.transactions = []
        self.billBudgets = []
        self.transactionBudgets = []
    }
    
    // MARK: - Secure Storage Methods
    
    func saveSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        
        // Create a dictionary with the correct types
        let userDataDict: [String: String] = [
            "id": id ?? "",
            "email": email ?? "",
            "name": name ?? "",
            "deviceIdentifier": deviceIdentifier,
            "lastLoginDate": String(lastLoginDate.timeIntervalSince1970)
        ]
        
        // Save user data to Keychain
        let userData = try JSONEncoder().encode(userDataDict)
        try secureStorage.saveToKeychain(key: "userData", data: userData)
        
        // Save user data to iCloud
        try await secureStorage.saveToiCloud(key: "userData", data: userData)
        
        // Set up iCloud sync
        try await secureStorage.syncWithiCloud()
    }
    
    func loadSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        
        // Try to load from Keychain first
        do {
            let userData = try secureStorage.loadFromKeychain(key: "userData")
            let userDict = try JSONDecoder().decode([String: String].self, from: userData)
            
            // Update user properties
            self.id = userDict["id"]
            self.email = userDict["email"]
            self.name = userDict["name"]
            if let deviceId = userDict["deviceIdentifier"] { self.deviceIdentifier = deviceId }
            if let timestamp = userDict["lastLoginDate"],
               let timeInterval = Double(timestamp) {
                self.lastLoginDate = Date(timeIntervalSince1970: timeInterval)
            }
        } catch {
            // If Keychain fails, try iCloud
            do {
                let userData = try await secureStorage.loadFromiCloud(key: "userData")
                let userDict = try JSONDecoder().decode([String: String].self, from: userData)
                
                // Update user properties
                self.id = userDict["id"]
                self.email = userDict["email"]
                self.name = userDict["name"]
                if let deviceId = userDict["deviceIdentifier"] { self.deviceIdentifier = deviceId }
                if let timestamp = userDict["lastLoginDate"],
                   let timeInterval = Double(timestamp) {
                    self.lastLoginDate = Date(timeIntervalSince1970: timeInterval)
                }
            } catch {
                // If both fail, keep the current data
                print("Failed to load secure data: \(error)")
            }
        }
    }
    
    func deleteSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        
        // Delete from both Keychain and iCloud
        try secureStorage.deleteFromKeychain(key: "userData")
        try await secureStorage.deleteFromiCloud(key: "userData")
    }
    
    // MARK: - Device Synchronization
    
    func isCurrentDevice() -> Bool {
        return deviceIdentifier == UIDevice.current.identifierForVendor?.uuidString
    }
    
    func updateLastLoginDate() {
        lastLoginDate = Date()
        Task {
            try? await saveSecureData()
        }
    }
} 