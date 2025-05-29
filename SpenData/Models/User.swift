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
    @Relationship(deleteRule: .cascade) var incomes: [Income]?
    @Relationship(deleteRule: .cascade) var financialGoals: [FinancialGoal]?
    
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
        self.incomes = []
        self.financialGoals = []
    }
    
    // MARK: - Secure Storage Methods
    
    private func createCloudKitKey() -> String {
        let sanitizedId = (id ?? UUID().uuidString).replacingOccurrences(of: "-", with: "")
        return "user_\(sanitizedId)"
    }
    
    func saveSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        
        let userDataDict: [String: String] = [
            "id": id ?? "",
            "email": email ?? "",
            "name": name ?? "",
            "createdAt": String(createdAt.timeIntervalSince1970),
            "lastLoginDate": String(lastLoginDate.timeIntervalSince1970),
            "deviceIdentifier": deviceIdentifier
        ]
        
        let cloudKitKey = createCloudKitKey()
        
        let userData = try JSONEncoder().encode(userDataDict)
        try secureStorage.saveToKeychain(key: cloudKitKey, data: userData)
        try await secureStorage.saveToiCloud(key: cloudKitKey, data: userData)
        
        // Save related data
        if let bills = bills {
            for bill in bills {
                try await bill.saveSecureData()
            }
        }
        
        if let transactions = transactions {
            for transaction in transactions {
                try await transaction.saveSecureData()
            }
        }
        
        if let billBudgets = billBudgets {
            for budget in billBudgets {
                try await budget.saveSecureData()
            }
        }
        
        if let transactionBudgets = transactionBudgets {
            for budget in transactionBudgets {
                try await budget.saveSecureData()
            }
        }
        
        if let incomes = incomes {
            for income in incomes {
                try await income.saveSecureData()
            }
        }
        
        if let financialGoals = financialGoals {
            for goal in financialGoals {
                try await goal.saveSecureData()
            }
        }
    }
    
    func loadSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        let cloudKitKey = createCloudKitKey()
        
        // Try to load from iCloud first
        if let data = try? await secureStorage.loadFromiCloud(key: cloudKitKey) {
            let userDataDict = try JSONDecoder().decode([String: String].self, from: data)
            updateFromDictionary(userDataDict)
        } else if let data = try? secureStorage.loadFromKeychain(key: cloudKitKey) {
            // Fall back to Keychain if iCloud fails
            let userDataDict = try JSONDecoder().decode([String: String].self, from: data)
            updateFromDictionary(userDataDict)
        }
    }
    
    private func updateFromDictionary(_ dict: [String: String]) {
        id = dict["id"]
        email = dict["email"]
        name = dict["name"]
        
        if let createdAtString = dict["createdAt"],
           let createdAtTimeInterval = Double(createdAtString) {
            createdAt = Date(timeIntervalSince1970: createdAtTimeInterval)
        }
        
        if let lastLoginString = dict["lastLoginDate"],
           let lastLoginTimeInterval = Double(lastLoginString) {
            lastLoginDate = Date(timeIntervalSince1970: lastLoginTimeInterval)
        }
        
        deviceIdentifier = dict["deviceIdentifier"] ?? deviceIdentifier
    }
    
    func deleteSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        
        // Delete from both Keychain and iCloud
        try secureStorage.deleteFromKeychain(key: createCloudKitKey())
        try await secureStorage.deleteFromiCloud(key: createCloudKitKey())
    }
    
    // MARK: - Device Synchronization
    
    func isCurrentDevice() -> Bool {
        return deviceIdentifier == UIDevice.current.identifierForVendor?.uuidString
    }
    
    func updateLastLoginDate() {
        lastLoginDate = Date()
    }
} 