import Foundation
import SwiftData
import SwiftUI

enum BudgetPeriod: String, Codable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    
    func nextPeriodDate(from date: Date) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
}

@Model
final class BillBudget {
    var id: String?
    var category: String?
    var amount: Double?
    var isPaid: Bool = false
    var dueDate: Date?
    var createdAt: Date?
    
    // Relationship to User
    @Relationship(inverse: \User.billBudgets) var user: User?
    
    init(id: String = UUID().uuidString,
         category: String,
         amount: Double,
         dueDate: Date) {
        self.id = id
        self.category = category
        self.amount = amount
        self.dueDate = dueDate
        self.createdAt = Date()
    }
    
    // MARK: - Secure Storage Methods
    
    private func createCloudKitKey() -> String {
        let sanitizedId = (id ?? UUID().uuidString).replacingOccurrences(of: "-", with: "")
        return "bill_budget_\(sanitizedId)"
    }
    
    func saveSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        
        let budgetDataDict: [String: String] = [
            "id": id ?? "",
            "category": category ?? "",
            "amount": String(amount ?? 0.0),
            "isPaid": String(isPaid),
            "dueDate": String(dueDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970),
            "createdAt": String(createdAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970)
        ]
        
        let cloudKitKey = createCloudKitKey()
        
        let budgetData = try JSONEncoder().encode(budgetDataDict)
        try secureStorage.saveToKeychain(key: cloudKitKey, data: budgetData)
        try await secureStorage.saveToiCloud(key: cloudKitKey, data: budgetData)
        
        NotificationCenter.default.post(name: .transactionDataDidChange, object: nil)
    }
    
    func loadSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        let cloudKitKey = createCloudKitKey()
        
        do {
            let budgetData = try secureStorage.loadFromKeychain(key: cloudKitKey)
            let budgetDict = try JSONDecoder().decode([String: String].self, from: budgetData)
            
            self.id = budgetDict["id"]
            self.category = budgetDict["category"]
            if let amountStr = budgetDict["amount"], let amount = Double(amountStr) {
                self.amount = amount
            }
            self.isPaid = budgetDict["isPaid"] == "true"
            if let timestamp = budgetDict["dueDate"],
               let timeInterval = Double(timestamp) {
                self.dueDate = Date(timeIntervalSince1970: timeInterval)
            }
            if let timestamp = budgetDict["createdAt"],
               let timeInterval = Double(timestamp) {
                self.createdAt = Date(timeIntervalSince1970: timeInterval)
            }
        } catch {
            do {
                let budgetData = try await secureStorage.loadFromiCloud(key: cloudKitKey)
                let budgetDict = try JSONDecoder().decode([String: String].self, from: budgetData)
                
                self.id = budgetDict["id"]
                self.category = budgetDict["category"]
                if let amountStr = budgetDict["amount"], let amount = Double(amountStr) {
                    self.amount = amount
                }
                self.isPaid = budgetDict["isPaid"] == "true"
                if let timestamp = budgetDict["dueDate"],
                   let timeInterval = Double(timestamp) {
                    self.dueDate = Date(timeIntervalSince1970: timeInterval)
                }
                if let timestamp = budgetDict["createdAt"],
                   let timeInterval = Double(timestamp) {
                    self.createdAt = Date(timeIntervalSince1970: timeInterval)
                }
            } catch {
                print("Failed to load secure data: \(error)")
            }
        }
    }
    
    func deleteSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        let cloudKitKey = createCloudKitKey()
        
        try secureStorage.deleteFromKeychain(key: cloudKitKey)
        try await secureStorage.deleteFromiCloud(key: cloudKitKey)
    }
}

@Model
final class TransactionBudget {
    var id: String?
    var category: String?
    var limit: Double?
    var period: String?
    var startDate: Date?
    var createdAt: Date?
    var isActive: Bool = true
    
    // Relationship to User
    @Relationship(inverse: \User.transactionBudgets) var user: User?
    
    init(id: String = UUID().uuidString,
         category: String,
         limit: Double,
         period: BudgetPeriod,
         startDate: Date = Date()) {
        self.id = id
        self.category = category
        self.limit = limit
        self.period = period.rawValue
        self.startDate = startDate
        self.createdAt = Date()
    }
    
    // MARK: - Secure Storage Methods
    
    private func createCloudKitKey() -> String {
        let sanitizedId = (id ?? UUID().uuidString).replacingOccurrences(of: "-", with: "")
        return "transaction_budget_\(sanitizedId)"
    }
    
    func saveSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        
        let budgetDataDict: [String: String] = [
            "id": id ?? "",
            "category": category ?? "",
            "limit": String(limit ?? 0.0),
            "period": period ?? "",
            "startDate": String(startDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970),
            "createdAt": String(createdAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970),
            "isActive": String(isActive)
        ]
        
        let cloudKitKey = createCloudKitKey()
        
        let budgetData = try JSONEncoder().encode(budgetDataDict)
        try secureStorage.saveToKeychain(key: cloudKitKey, data: budgetData)
        try await secureStorage.saveToiCloud(key: cloudKitKey, data: budgetData)
        
        NotificationCenter.default.post(name: .transactionDataDidChange, object: nil)
    }
    
    func loadSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        let cloudKitKey = createCloudKitKey()
        
        do {
            let budgetData = try secureStorage.loadFromKeychain(key: cloudKitKey)
            let budgetDict = try JSONDecoder().decode([String: String].self, from: budgetData)
            
            self.id = budgetDict["id"]
            self.category = budgetDict["category"]
            if let limitStr = budgetDict["limit"], let limit = Double(limitStr) {
                self.limit = limit
            }
            self.period = budgetDict["period"]
            if let timestamp = budgetDict["startDate"],
               let timeInterval = Double(timestamp) {
                self.startDate = Date(timeIntervalSince1970: timeInterval)
            }
            self.isActive = budgetDict["isActive"] == "true"
            if let timestamp = budgetDict["createdAt"],
               let timeInterval = Double(timestamp) {
                self.createdAt = Date(timeIntervalSince1970: timeInterval)
            }
        } catch {
            do {
                let budgetData = try await secureStorage.loadFromiCloud(key: cloudKitKey)
                let budgetDict = try JSONDecoder().decode([String: String].self, from: budgetData)
                
                self.id = budgetDict["id"]
                self.category = budgetDict["category"]
                if let limitStr = budgetDict["limit"], let limit = Double(limitStr) {
                    self.limit = limit
                }
                self.period = budgetDict["period"]
                if let timestamp = budgetDict["startDate"],
                   let timeInterval = Double(timestamp) {
                    self.startDate = Date(timeIntervalSince1970: timeInterval)
                }
                self.isActive = budgetDict["isActive"] == "true"
                if let timestamp = budgetDict["createdAt"],
                   let timeInterval = Double(timestamp) {
                    self.createdAt = Date(timeIntervalSince1970: timeInterval)
                }
            } catch {
                print("Failed to load secure data: \(error)")
            }
        }
    }
    
    func deleteSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        let cloudKitKey = createCloudKitKey()
        
        try secureStorage.deleteFromKeychain(key: cloudKitKey)
        try await secureStorage.deleteFromiCloud(key: cloudKitKey)
    }
} 