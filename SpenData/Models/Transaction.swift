import Foundation
import SwiftData
import SwiftUI

enum TransactionCategory: String, Codable, CaseIterable {
    case uncategorized = "Uncategorized"
    case groceries = "🛒 Groceries"
    case diningOut = "🍽️ Dining Out"
    case coffee = "☕ Coffee"
    case bars = "🍻 Bars & Alcohol"
    case fastFood = "🍔 Fast Food"
    case snacks = "🍫 Snacks"
    case clothing = "👕 Clothing"
    case shoes = "👟 Shoes"
    case accessories = "👜 Accessories"
    case electronics = "💻 Electronics"
    case books = "📚 Books"
    case hobbies = "🎨 Hobbies"
    case gifts = "🎁 Gifts"
    case homeDecor = "🛋️ Home Decor"
    case entertainment = "🎮 Entertainment"
    case events = "🎫 Events & Tickets"
    case movies = "🎬 Movies"
    case music = "🎵 Music"
    case games = "🕹️ Games"
    case travel = "✈️ Travel"
    case flight = "🛫 Flight"
    case hotel = "🏨 Hotel"
    case taxi = "🚕 Taxi / Ride Share"
    case publicTransport = "🚌 Public Transport"
    case fuel = "⛽ Fuel"
    case parking = "🅿️ Parking"
    case tolls = "🛣️ Tolls"
    case petSupplies = "🐾 Pet Supplies"
    case vet = "🩺 Vet Visits"
    case pharmacy = "🧪 Pharmacy"
    case doctorVisit = "🩻 Doctor Visit"
    case therapy = "🧠 Therapy"
    case personalCare = "🧴 Personal Care"
    case hair = "💇 Hair"
    case beauty = "💅 Beauty & Nails"
    case spa = "🧖 Spa & Wellness"
    case sports = "🏈 Sports"
    case fitness = "🏋️ Gym & Fitness"
    case stationery = "✏️ Stationery"
    case cleaning = "🧽 Cleaning Supplies"
    case hardware = "🔩 Hardware / Tools"
    case donations = "🙏 Donations"
    case miscellaneous = "📁 Miscellaneous"

    
    var color: Color {
        switch self {
        case .uncategorized: return .gray
        case .groceries: return .mint
        case .diningOut, .coffee, .bars, .fastFood, .snacks: return .orange
        case .clothing, .shoes, .accessories, .electronics, .books, .homeDecor, .stationery: return .blue
        case .hobbies, .entertainment, .events, .movies, .music, .games, .sports: return .purple
        case .travel, .flight, .hotel: return .indigo
        case .taxi, .publicTransport, .fuel, .parking, .tolls: return .green
        case .petSupplies, .vet: return .teal
        case .pharmacy, .doctorVisit, .therapy: return .pink
        case .personalCare, .hair, .beauty, .spa: return .cyan
        case .fitness: return .mint
        case .gifts, .donations: return .yellow
        case .cleaning, .hardware: return .brown
        case .miscellaneous: return .gray
        }
    }
}

@Model
final class Transaction {
    var id: String?
    var name: String?
    var amount: Double = 0.0
    var category: String?
    var date: Date = Date()
    var notes: String?
    var createdAt: Date = Date()
    var isShared: Bool = false
    
    // Relationship to User
    @Relationship(inverse: \User.transactions) var user: User?
    
    init(id: String = UUID().uuidString,
         name: String,
         amount: Double,
         category: String,
         date: Date,
         notes: String? = nil,
         isShared: Bool = false) {
        self.id = id
        self.name = name
        self.amount = amount
        self.category = category
        self.date = date
        self.notes = notes
        self.isShared = isShared
    }
    
    // MARK: - Secure Storage Methods
    
    private func createCloudKitKey() -> String {
        let sanitizedId = (id ?? UUID().uuidString).replacingOccurrences(of: "-", with: "")
        return "transaction_\(sanitizedId)"
    }
    
    func saveSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        
        let transactionDataDict: [String: String] = [
            "id": id ?? "",
            "name": name ?? "",
            "amount": String(amount),
            "category": category ?? "",
            "date": String(date.timeIntervalSince1970),
            "notes": notes ?? "",
            "createdAt": String(createdAt.timeIntervalSince1970),
            "isShared": String(isShared)
        ]
        
        let cloudKitKey = createCloudKitKey()
        
        let transactionData = try JSONEncoder().encode(transactionDataDict)
        try secureStorage.saveToKeychain(key: cloudKitKey, data: transactionData)
        try await secureStorage.saveToiCloud(key: cloudKitKey, data: transactionData)
        
        NotificationCenter.default.post(name: .transactionDataDidChange, object: nil)
    }
    
    func loadSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        let cloudKitKey = createCloudKitKey()
        
        do {
            let transactionData = try secureStorage.loadFromKeychain(key: cloudKitKey)
            let transactionDict = try JSONDecoder().decode([String: String].self, from: transactionData)
            
            self.id = transactionDict["id"]
            self.name = transactionDict["name"]
            if let amountStr = transactionDict["amount"], let amount = Double(amountStr) {
                self.amount = amount
            }
            self.category = transactionDict["category"]
            if let timestamp = transactionDict["date"],
               let timeInterval = Double(timestamp) {
                self.date = Date(timeIntervalSince1970: timeInterval)
            }
            self.notes = transactionDict["notes"]
            if let timestamp = transactionDict["createdAt"],
               let timeInterval = Double(timestamp) {
                self.createdAt = Date(timeIntervalSince1970: timeInterval)
            }
            if let isSharedStr = transactionDict["isShared"] {
                self.isShared = isSharedStr == "true"
            }
        } catch {
            do {
                let transactionData = try await secureStorage.loadFromiCloud(key: cloudKitKey)
                let transactionDict = try JSONDecoder().decode([String: String].self, from: transactionData)
                
                self.id = transactionDict["id"]
                self.name = transactionDict["name"]
                if let amountStr = transactionDict["amount"], let amount = Double(amountStr) {
                    self.amount = amount
                }
                self.category = transactionDict["category"]
                if let timestamp = transactionDict["date"],
                   let timeInterval = Double(timestamp) {
                    self.date = Date(timeIntervalSince1970: timeInterval)
                }
                self.notes = transactionDict["notes"]
                if let timestamp = transactionDict["createdAt"],
                   let timeInterval = Double(timestamp) {
                    self.createdAt = Date(timeIntervalSince1970: timeInterval)
                }
                if let isSharedStr = transactionDict["isShared"] {
                    self.isShared = isSharedStr == "true"
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
