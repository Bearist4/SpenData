import SwiftUI
import SwiftData

@MainActor
struct PreviewData {
    static func createPreviewContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: User.self, Bill.self, configurations: config)
        
        // Create sample user
        let user = createSampleUser()
        container.mainContext.insert(user)
        
        // Create and insert sample bills
        let bills = createSampleBills(for: user)
        for bill in bills {
            container.mainContext.insert(bill)
        }
        
        return container
    }
    
    static func createSampleUser() -> User {
        return User(id: UUID().uuidString, email: "john@example.com", name: "John Doe")
    }
    
    static func createSampleBills(for user: User) -> [Bill] {
        let calendar = Calendar.current
        let today = Date()
        
        let bills = [
            Bill(name: "Rent", amount: 1200, category: BillCategory.housing.rawValue, issuer: "Landlord Co", firstInstallment: today, recurrence: BillRecurrence.monthly.rawValue),
            Bill(name: "Electricity", amount: 150, category: BillCategory.utilities.rawValue, issuer: "Power Co", firstInstallment: calendar.date(byAdding: .day, value: -5, to: today)!, recurrence: BillRecurrence.monthly.rawValue),
            Bill(name: "Internet", amount: 80, category: BillCategory.utilities.rawValue, issuer: "Fiber Co", firstInstallment: calendar.date(byAdding: .day, value: -3, to: today)!, recurrence: BillRecurrence.monthly.rawValue),
            Bill(name: "Car Insurance", amount: 200, category: BillCategory.insurance.rawValue, issuer: "SafeDrive", firstInstallment: calendar.date(byAdding: .day, value: -2, to: today)!, recurrence: BillRecurrence.monthly.rawValue),
            Bill(name: "Netflix", amount: 15.99, category: BillCategory.subscriptions.rawValue, issuer: "Netflix", firstInstallment: calendar.date(byAdding: .day, value: -1, to: today)!, recurrence: BillRecurrence.monthly.rawValue),
            Bill(name: "Gym Membership", amount: 50, category: BillCategory.subscriptions.rawValue, issuer: "FitLife", firstInstallment: today, recurrence: BillRecurrence.monthly.rawValue, isShared: true, numberOfShares: 2)
        ]
        
        // Set the user for each bill
        bills.forEach { $0.user = user }
        
        return bills
    }
} 
