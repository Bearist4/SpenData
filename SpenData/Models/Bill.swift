import Foundation
import SwiftData
import SwiftUI

enum BillCategory: String, Codable, CaseIterable {
    case uncategorized = "Uncategorized"
    case housing = "🏡 Housing"
    case utilities = "💡 Utilities"
    case transportation = "🚗 Transportation"
    case insurance = "🛡️ Insurance"
    case subscriptions = "📦 Subscriptions"
    case groceries = "🛒 Groceries"
    case phone = "📱 Phone"
    case internet = "🌐 Internet"
    case medical = "💊 Medical"
    case debt = "💳 Debt"
    case childcare = "🧒 Childcare"
    case education = "🎓 Education"
    case entertainment = "🎮 Entertainment"
    case savings = "💰 Savings"
    case donations = "🙏 Donations"
    case personalCare = "🧴 Personal Care"
    case pets = "🐾 Pets"
    case travel = "✈️ Travel"
    case taxes = "🧾 Taxes"
    case other = "📁 Other"
    
    var color: Color {
        switch self {
        case .uncategorized: return .gray
        case .housing: return .blue
        case .utilities: return .orange
        case .transportation: return .green
        case .insurance: return .red
        case .subscriptions: return .purple
        case .groceries: return .mint
        case .phone: return .cyan
        case .internet: return .indigo
        case .medical: return .pink
        case .debt: return .red
        case .childcare: return .yellow
        case .education: return .blue
        case .entertainment: return .purple
        case .savings: return .green
        case .donations: return .orange
        case .personalCare: return .pink
        case .pets: return .brown
        case .travel: return .cyan
        case .taxes: return .red
        case .other: return .gray
        }
    }
}

enum BillRecurrence: String, Codable, CaseIterable {
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"
    case custom = "Custom"
    
    func nextDueDate(from date: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        case .custom:
            return date // Will be set by user
        }
    }
    
    func daysUntilNextDue(from date: Date) -> Int {
        let nextDue = nextDueDate(from: date)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: date, to: nextDue)
        return components.day ?? 0
    }
}

@Model
final class Bill {
    var id: String?
    var name: String?
    var amount: Double = 0.0
    var category: String?
    var issuer: String?
    var createdAt: Date = Date()
    var firstInstallment: Date = Date()
    var recurrence: String?
    var isShared: Bool = false
    var numberOfShares: Int = 1
    
    // Relationship to User
    @Relationship(inverse: \User.bills) var user: User?
    
    init(id: String = UUID().uuidString,
         name: String,
         amount: Double,
         category: String,
         issuer: String,
         firstInstallment: Date,
         recurrence: String,
         isShared: Bool = false,
         numberOfShares: Int = 1) {
        self.id = id
        self.name = name
        self.amount = amount
        self.category = category
        self.issuer = issuer
        self.firstInstallment = firstInstallment
        self.recurrence = recurrence
        self.isShared = isShared
        self.numberOfShares = numberOfShares
    }
    
    // MARK: - Secure Storage Methods
    
    private func createCloudKitKey() -> String {
        // Remove hyphens and other special characters from UUID
        let sanitizedId = (id ?? UUID().uuidString).replacingOccurrences(of: "-", with: "")
        return "bill_\(sanitizedId)"
    }
    
    func saveSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        
        // Create a dictionary with the correct types
        let billDataDict: [String: String] = [
            "id": id ?? "",
            "name": name ?? "",
            "amount": String(amount),
            "category": category ?? "",
            "issuer": issuer ?? "",
            "createdAt": String(createdAt.timeIntervalSince1970),
            "firstInstallment": String(firstInstallment.timeIntervalSince1970),
            "recurrence": recurrence ?? "",
            "isShared": String(isShared),
            "numberOfShares": String(numberOfShares)
        ]
        
        // Debug: Print the data being sent
        print("📤 Sending bill data to iCloud:")
        print("Bill ID: \(id ?? "nil")")
        print("Name: \(name ?? "nil")")
        print("Amount: \(amount)")
        print("Category: \(category ?? "nil")")
        print("Issuer: \(issuer ?? "nil")")
        print("Created At: \(createdAt)")
        print("First Installment: \(firstInstallment)")
        print("Recurrence: \(recurrence ?? "nil")")
        print("Is Shared: \(isShared)")
        print("Number of Shares: \(numberOfShares)")
        
        // Create CloudKit-safe key
        let cloudKitKey = createCloudKitKey()
        print("🔑 Using CloudKit key: \(cloudKitKey)")
        
        // Save bill data to Keychain
        let billData = try JSONEncoder().encode(billDataDict)
        try secureStorage.saveToKeychain(key: cloudKitKey, data: billData)
        
        // Save bill data to iCloud
        try await secureStorage.saveToiCloud(key: cloudKitKey, data: billData)
        
        // Notify other devices about the change
        NotificationCenter.default.post(name: .billDataDidChange, object: nil)
    }
    
    func loadSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        let cloudKitKey = createCloudKitKey()
        
        // Try to load from Keychain first
        do {
            let billData = try secureStorage.loadFromKeychain(key: cloudKitKey)
            let billDict = try JSONDecoder().decode([String: String].self, from: billData)
            
            // Update bill properties
            self.id = billDict["id"]
            self.name = billDict["name"]
            if let amountStr = billDict["amount"], let amount = Double(amountStr) {
                self.amount = amount
            }
            self.category = billDict["category"]
            self.issuer = billDict["issuer"]
            if let timestamp = billDict["createdAt"],
               let timeInterval = Double(timestamp) {
                self.createdAt = Date(timeIntervalSince1970: timeInterval)
            }
            if let timestamp = billDict["firstInstallment"],
               let timeInterval = Double(timestamp) {
                self.firstInstallment = Date(timeIntervalSince1970: timeInterval)
            }
            self.recurrence = billDict["recurrence"]
            if let isSharedStr = billDict["isShared"] {
                self.isShared = isSharedStr == "true"
            }
            if let sharesStr = billDict["numberOfShares"],
               let shares = Int(sharesStr) {
                self.numberOfShares = shares
            }
        } catch {
            // If Keychain fails, try iCloud
            do {
                let billData = try await secureStorage.loadFromiCloud(key: cloudKitKey)
                let billDict = try JSONDecoder().decode([String: String].self, from: billData)
                
                // Update bill properties
                self.id = billDict["id"]
                self.name = billDict["name"]
                if let amountStr = billDict["amount"], let amount = Double(amountStr) {
                    self.amount = amount
                }
                self.category = billDict["category"]
                self.issuer = billDict["issuer"]
                if let timestamp = billDict["createdAt"],
                   let timeInterval = Double(timestamp) {
                    self.createdAt = Date(timeIntervalSince1970: timeInterval)
                }
                if let timestamp = billDict["firstInstallment"],
                   let timeInterval = Double(timestamp) {
                    self.firstInstallment = Date(timeIntervalSince1970: timeInterval)
                }
                self.recurrence = billDict["recurrence"]
                if let isSharedStr = billDict["isShared"] {
                    self.isShared = isSharedStr == "true"
                }
                if let sharesStr = billDict["numberOfShares"],
                   let shares = Int(sharesStr) {
                    self.numberOfShares = shares
                }
            } catch {
                // If both fail, keep the current data
                print("Failed to load secure data: \(error)")
            }
        }
    }
    
    func deleteSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        let cloudKitKey = createCloudKitKey()
        
        // Delete from both Keychain and iCloud
        try secureStorage.deleteFromKeychain(key: cloudKitKey)
        try await secureStorage.deleteFromiCloud(key: cloudKitKey)
    }
} 
