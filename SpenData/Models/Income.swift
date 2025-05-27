import Foundation
import SwiftData
import SwiftUI

enum IncomeCategory: String, Codable, CaseIterable {
    case salary = "💰 Salary"
    case freelance = "💼 Freelance"
    case investments = "📈 Investments"
    case rental = "🏠 Rental"
    case business = "🏢 Business"
    case sideHustle = "🎯 Side Hustle"
    case gifts = "🎁 Gifts"
    case other = "📁 Other"
    
    var color: Color {
        switch self {
        case .salary: return .blue
        case .freelance: return .green
        case .investments: return .purple
        case .rental: return .orange
        case .business: return .indigo
        case .sideHustle: return .mint
        case .gifts: return .pink
        case .other: return .gray
        }
    }
}

enum IncomeFrequency: String, Codable, CaseIterable {
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"
    case custom = "Custom"
    
    func nextDueDate(from date: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date) ?? date
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
}

enum PaymentTiming: String, Codable, CaseIterable {
    case beginningOfMonth = "Beginning of Month"
    case endOfMonth = "End of Month"
    
    func getPaymentDate(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        
        switch self {
        case .beginningOfMonth:
            // Get the first day of the month
            guard let firstDay = calendar.date(from: components) else { return date }
            // Find the first business day
            return findNextBusinessDay(from: firstDay)
        case .endOfMonth:
            // Get the last day of the month
            guard let lastDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: calendar.date(from: components)!) else { return date }
            // Find the last business day
            return findPreviousBusinessDay(from: lastDay)
        }
    }
    
    private func findNextBusinessDay(from date: Date) -> Date {
        let calendar = Calendar.current
        var currentDate = date
        
        while calendar.isDateInWeekend(currentDate) {
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return currentDate
    }
    
    private func findPreviousBusinessDay(from date: Date) -> Date {
        let calendar = Calendar.current
        var currentDate = date
        
        while calendar.isDateInWeekend(currentDate) {
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        return currentDate
    }
}

@Model
final class Income {
    var id: String?
    var name: String?
    var amount: Double = 0.0
    var category: String?
    var issuer: String?
    var createdAt: Date = Date()
    var firstPayment: Date = Date()
    var frequency: String?
    var paymentTiming: String?
    var notes: String?
    
    // Relationship to User
    @Relationship(inverse: \User.incomes) var user: User?
    
    init(id: String = UUID().uuidString,
         name: String,
         amount: Double,
         category: String,
         issuer: String,
         firstPayment: Date,
         frequency: String,
         paymentTiming: String? = nil,
         notes: String? = nil) {
        self.id = id
        self.name = name
        self.amount = amount
        self.category = category
        self.issuer = issuer
        self.firstPayment = firstPayment
        self.frequency = frequency
        self.paymentTiming = paymentTiming
        self.notes = notes
    }
    
    var nextPaymentDate: Date {
        guard let frequencyString = frequency,
              let frequency = IncomeFrequency(rawValue: frequencyString),
              let timingString = paymentTiming,
              let timing = PaymentTiming(rawValue: timingString) else {
            return firstPayment
        }
        
        let nextDate = frequency.nextDueDate(from: firstPayment)
        return timing.getPaymentDate(for: nextDate)
    }
    
    var effectiveMonth: Date {
        guard let timingString = paymentTiming,
              let timing = PaymentTiming(rawValue: timingString) else {
            return firstPayment
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: firstPayment)
        
        // If payment is at the end of month, it counts for the next month
        if timing == .endOfMonth {
            return calendar.date(byAdding: .month, value: 1, to: calendar.date(from: components)!) ?? firstPayment
        }
        
        return calendar.date(from: components) ?? firstPayment
    }
    
    // MARK: - Secure Storage Methods
    
    private func createCloudKitKey() -> String {
        let sanitizedId = (id ?? UUID().uuidString).replacingOccurrences(of: "-", with: "")
        return "income_\(sanitizedId)"
    }
    
    func saveSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        
        let incomeDataDict: [String: String] = [
            "id": id ?? "",
            "name": name ?? "",
            "amount": String(amount),
            "category": category ?? "",
            "issuer": issuer ?? "",
            "firstPayment": String(firstPayment.timeIntervalSince1970),
            "frequency": frequency ?? "",
            "paymentTiming": paymentTiming ?? "",
            "notes": notes ?? "",
            "createdAt": String(createdAt.timeIntervalSince1970)
        ]
        
        let cloudKitKey = createCloudKitKey()
        
        let incomeData = try JSONEncoder().encode(incomeDataDict)
        try secureStorage.saveToKeychain(key: cloudKitKey, data: incomeData)
        try await secureStorage.saveToiCloud(key: cloudKitKey, data: incomeData)
    }
    
    func loadSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        let cloudKitKey = createCloudKitKey()
        
        // Try to load from Keychain first
        do {
            let incomeData = try secureStorage.loadFromKeychain(key: cloudKitKey)
            let incomeDict = try JSONDecoder().decode([String: String].self, from: incomeData)
            
            // Update income properties
            self.id = incomeDict["id"]
            self.name = incomeDict["name"]
            if let amountStr = incomeDict["amount"], let amount = Double(amountStr) {
                self.amount = amount
            }
            self.category = incomeDict["category"]
            self.issuer = incomeDict["issuer"]
            if let timestamp = incomeDict["firstPayment"],
               let timeInterval = Double(timestamp) {
                self.firstPayment = Date(timeIntervalSince1970: timeInterval)
            }
            self.frequency = incomeDict["frequency"]
            self.paymentTiming = incomeDict["paymentTiming"]
            self.notes = incomeDict["notes"]
            if let timestamp = incomeDict["createdAt"],
               let timeInterval = Double(timestamp) {
                self.createdAt = Date(timeIntervalSince1970: timeInterval)
            }
        } catch {
            // If Keychain fails, try iCloud
            do {
                let incomeData = try await secureStorage.loadFromiCloud(key: cloudKitKey)
                let incomeDict = try JSONDecoder().decode([String: String].self, from: incomeData)
                
                // Update income properties
                self.id = incomeDict["id"]
                self.name = incomeDict["name"]
                if let amountStr = incomeDict["amount"], let amount = Double(amountStr) {
                    self.amount = amount
                }
                self.category = incomeDict["category"]
                self.issuer = incomeDict["issuer"]
                if let timestamp = incomeDict["firstPayment"],
                   let timeInterval = Double(timestamp) {
                    self.firstPayment = Date(timeIntervalSince1970: timeInterval)
                }
                self.frequency = incomeDict["frequency"]
                self.paymentTiming = incomeDict["paymentTiming"]
                self.notes = incomeDict["notes"]
                if let timestamp = incomeDict["createdAt"],
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