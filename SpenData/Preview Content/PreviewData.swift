import SwiftUI
import SwiftData

@MainActor
struct PreviewData {
    static func createPreviewContainer() -> ModelContainer {
        let schema = Schema([
            User.self,
            Transaction.self,
            Bill.self,
            BillBudget.self,
            TransactionBudget.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            insertSampleData(into: container)
            return container
        } catch {
            fatalError("Could not create preview container: \(error.localizedDescription)")
        }
    }
    
    private static func insertSampleData(into container: ModelContainer) {
        let context = container.mainContext
        
        // Create sample user
        let user = User(email: "preview@example.com", name: "Preview User")
        context.insert(user)
        
        // Create sample transactions
        createSampleTransactions(for: user)
        
        // Create sample bills
        createSampleBills(for: user)
        
        // Create sample budgets
        createSampleBudgets(for: user)
    }
    
    private static func createSampleTransactions(for user: User) {
        let transactions = [
            // Recent transactions (last 2 weeks)
            Transaction(name: "Grocery Shopping", amount: 45.99, category: TransactionCategory.groceries.rawValue, date: Date().addingTimeInterval(-86400), notes: "Weekly groceries at Whole Foods"),
            Transaction(name: "Lunch with Team", amount: 25.50, category: TransactionCategory.diningOut.rawValue, date: Date().addingTimeInterval(-172800), notes: "Team lunch at Italian restaurant"),
            Transaction(name: "New Running Shoes", amount: 89.99, category: TransactionCategory.shoes.rawValue, date: Date().addingTimeInterval(-259200), notes: "Nike running shoes"),
            Transaction(name: "Uber to Airport", amount: 45.00, category: TransactionCategory.taxi.rawValue, date: Date().addingTimeInterval(-345600), notes: "Airport transfer"),
            Transaction(name: "Movie Night", amount: 24.99, category: TransactionCategory.movies.rawValue, date: Date().addingTimeInterval(-432000), notes: "Avengers tickets"),
            Transaction(name: "Pharmacy", amount: 35.75, category: TransactionCategory.pharmacy.rawValue, date: Date().addingTimeInterval(-518400), notes: "Prescription refill"),
            Transaction(name: "Haircut", amount: 30.00, category: TransactionCategory.hair.rawValue, date: Date().addingTimeInterval(-604800), notes: "Monthly trim"),
            Transaction(name: "Freelance Work", amount: 150.00, category: TransactionCategory.miscellaneous.rawValue, date: Date().addingTimeInterval(-691200), notes: "Website design project"),
            
            // Additional transactions (last month)
            Transaction(name: "Gym Membership", amount: 49.99, category: TransactionCategory.fitness.rawValue, date: Date().addingTimeInterval(-864000), notes: "Monthly gym fee"),
            Transaction(name: "Netflix Subscription", amount: 15.99, category: TransactionCategory.entertainment.rawValue, date: Date().addingTimeInterval(-950400), notes: "Monthly subscription"),
            Transaction(name: "Coffee Shop", amount: 4.50, category: TransactionCategory.coffee.rawValue, date: Date().addingTimeInterval(-1036800), notes: "Morning coffee"),
            Transaction(name: "Gas Station", amount: 45.00, category: TransactionCategory.fuel.rawValue, date: Date().addingTimeInterval(-1123200), notes: "Car fuel"),
            Transaction(name: "Amazon Purchase", amount: 29.99, category: TransactionCategory.electronics.rawValue, date: Date().addingTimeInterval(-1209600), notes: "New headphones"),
            Transaction(name: "Dentist Visit", amount: 150.00, category: TransactionCategory.doctorVisit.rawValue, date: Date().addingTimeInterval(-1296000), notes: "Regular checkup"),
            Transaction(name: "Concert Tickets", amount: 120.00, category: TransactionCategory.events.rawValue, date: Date().addingTimeInterval(-1382400), notes: "Taylor Swift concert"),
            Transaction(name: "New Phone Case", amount: 19.99, category: TransactionCategory.electronics.rawValue, date: Date().addingTimeInterval(-1468800), notes: "iPhone case"),
            Transaction(name: "Dry Cleaning", amount: 35.00, category: TransactionCategory.personalCare.rawValue, date: Date().addingTimeInterval(-1555200), notes: "Work clothes"),
            Transaction(name: "Birthday Gift", amount: 50.00, category: TransactionCategory.gifts.rawValue, date: Date().addingTimeInterval(-1641600), notes: "Friend's birthday"),
            
            // More transactions (last 2 months)
            Transaction(name: "New Laptop", amount: 1299.99, category: TransactionCategory.electronics.rawValue, date: Date().addingTimeInterval(-1728000), notes: "MacBook Pro"),
            Transaction(name: "Hotel Stay", amount: 250.00, category: TransactionCategory.hotel.rawValue, date: Date().addingTimeInterval(-1814400), notes: "Business trip"),
            Transaction(name: "Flight Tickets", amount: 450.00, category: TransactionCategory.flight.rawValue, date: Date().addingTimeInterval(-1900800), notes: "New York trip"),
            Transaction(name: "New Books", amount: 75.00, category: TransactionCategory.books.rawValue, date: Date().addingTimeInterval(-1987200), notes: "Programming books"),
            Transaction(name: "Art Supplies", amount: 85.00, category: TransactionCategory.hobbies.rawValue, date: Date().addingTimeInterval(-2073600), notes: "Painting supplies"),
            Transaction(name: "Pet Food", amount: 45.00, category: TransactionCategory.petSupplies.rawValue, date: Date().addingTimeInterval(-2160000), notes: "Monthly pet supplies"),
            Transaction(name: "Vet Visit", amount: 120.00, category: TransactionCategory.vet.rawValue, date: Date().addingTimeInterval(-2246400), notes: "Annual checkup"),
            Transaction(name: "New Clothes", amount: 150.00, category: TransactionCategory.clothing.rawValue, date: Date().addingTimeInterval(-2332800), notes: "Summer wardrobe"),
            Transaction(name: "Restaurant Dinner", amount: 85.00, category: TransactionCategory.diningOut.rawValue, date: Date().addingTimeInterval(-2419200), notes: "Anniversary dinner"),
            Transaction(name: "Public Transport", amount: 35.00, category: TransactionCategory.publicTransport.rawValue, date: Date().addingTimeInterval(-2505600), notes: "Monthly pass"),
            
            // Even more transactions (last 3 months)
            Transaction(name: "Home Decor", amount: 200.00, category: TransactionCategory.homeDecor.rawValue, date: Date().addingTimeInterval(-2592000), notes: "New furniture"),
            Transaction(name: "Spa Day", amount: 150.00, category: TransactionCategory.spa.rawValue, date: Date().addingTimeInterval(-2678400), notes: "Relaxation day"),
            Transaction(name: "New Games", amount: 60.00, category: TransactionCategory.games.rawValue, date: Date().addingTimeInterval(-2764800), notes: "PS5 games"),
            Transaction(name: "Music Subscription", amount: 9.99, category: TransactionCategory.music.rawValue, date: Date().addingTimeInterval(-2851200), notes: "Spotify Premium"),
            Transaction(name: "Charity Donation", amount: 100.00, category: TransactionCategory.donations.rawValue, date: Date().addingTimeInterval(-2937600), notes: "Monthly donation"),
            Transaction(name: "New Watch", amount: 299.99, category: TransactionCategory.accessories.rawValue, date: Date().addingTimeInterval(-3024000), notes: "Smart watch"),
            Transaction(name: "Parking Fee", amount: 25.00, category: TransactionCategory.parking.rawValue, date: Date().addingTimeInterval(-3110400), notes: "City parking"),
            Transaction(name: "Toll Road", amount: 15.00, category: TransactionCategory.tolls.rawValue, date: Date().addingTimeInterval(-3196800), notes: "Highway toll"),
            Transaction(name: "Beauty Products", amount: 65.00, category: TransactionCategory.beauty.rawValue, date: Date().addingTimeInterval(-3283200), notes: "Skincare products"),
            Transaction(name: "Sports Equipment", amount: 120.00, category: TransactionCategory.sports.rawValue, date: Date().addingTimeInterval(-3369600), notes: "New tennis racket"),
            
            // Recurring transactions (same day each month for 3 months)
            Transaction(name: "Monthly Groceries", amount: 180.00, category: TransactionCategory.groceries.rawValue, date: Date().addingTimeInterval(-2592000), notes: "Monthly grocery shopping", isShared: true),
            Transaction(name: "Monthly Groceries", amount: 180.00, category: TransactionCategory.groceries.rawValue, date: Date().addingTimeInterval(-5184000), notes: "Monthly grocery shopping", isShared: true),
            Transaction(name: "Monthly Groceries", amount: 180.00, category: TransactionCategory.groceries.rawValue, date: Date().addingTimeInterval(-7776000), notes: "Monthly grocery shopping", isShared: true),
            
            Transaction(name: "Weekly Coffee", amount: 4.50, category: TransactionCategory.coffee.rawValue, date: Date().addingTimeInterval(-604800), notes: "Monday coffee"),
            Transaction(name: "Weekly Coffee", amount: 4.50, category: TransactionCategory.coffee.rawValue, date: Date().addingTimeInterval(-1209600), notes: "Monday coffee"),
            Transaction(name: "Weekly Coffee", amount: 4.50, category: TransactionCategory.coffee.rawValue, date: Date().addingTimeInterval(-1814400), notes: "Monday coffee"),
            
            Transaction(name: "Monthly Haircut", amount: 30.00, category: TransactionCategory.hair.rawValue, date: Date().addingTimeInterval(-2592000), notes: "Regular haircut"),
            Transaction(name: "Monthly Haircut", amount: 30.00, category: TransactionCategory.hair.rawValue, date: Date().addingTimeInterval(-5184000), notes: "Regular haircut"),
            Transaction(name: "Monthly Haircut", amount: 30.00, category: TransactionCategory.hair.rawValue, date: Date().addingTimeInterval(-7776000), notes: "Regular haircut"),
            
            Transaction(name: "Monthly Gym", amount: 49.99, category: TransactionCategory.fitness.rawValue, date: Date().addingTimeInterval(-2592000), notes: "Monthly gym membership"),
            Transaction(name: "Monthly Gym", amount: 49.99, category: TransactionCategory.fitness.rawValue, date: Date().addingTimeInterval(-5184000), notes: "Monthly gym membership"),
            Transaction(name: "Monthly Gym", amount: 49.99, category: TransactionCategory.fitness.rawValue, date: Date().addingTimeInterval(-7776000), notes: "Monthly gym membership")
        ]
        
        for transaction in transactions {
            transaction.user = user
            user.transactions?.append(transaction)
        }
    }
    
    private static func createSampleBills(for user: User) {
        let calendar = Calendar.current
        let maxMonthsAhead = 12
        let sampleBills = [
            // Housing and Utilities
            (name: "Rent", amount: 1200.00, category: BillCategory.housing.rawValue, issuer: "Landlord Co", firstInstallment: Date().addingTimeInterval(86400 * 5), recurrence: BillRecurrence.monthly),
            (name: "Electricity", amount: 150.00, category: BillCategory.utilities.rawValue, issuer: "Power Co", firstInstallment: Date().addingTimeInterval(86400 * 3), recurrence: BillRecurrence.monthly),
            (name: "Water", amount: 80.00, category: BillCategory.utilities.rawValue, issuer: "Water Co", firstInstallment: Date().addingTimeInterval(86400 * 2), recurrence: BillRecurrence.monthly),
            (name: "Internet", amount: 79.99, category: BillCategory.internet.rawValue, issuer: "FiberNet", firstInstallment: Date().addingTimeInterval(86400 * 4), recurrence: BillRecurrence.monthly),
            (name: "Phone Bill", amount: 65.00, category: BillCategory.phone.rawValue, issuer: "MobileCo", firstInstallment: Date().addingTimeInterval(86400 * 6), recurrence: BillRecurrence.monthly),
            
            // Insurance and Transportation
            (name: "Car Insurance", amount: 200.00, category: BillCategory.insurance.rawValue, issuer: "SafeDrive", firstInstallment: Date().addingTimeInterval(86400 * 7), recurrence: BillRecurrence.monthly),
            (name: "Health Insurance", amount: 350.00, category: BillCategory.insurance.rawValue, issuer: "HealthCare Plus", firstInstallment: Date().addingTimeInterval(86400 * 8), recurrence: BillRecurrence.monthly),
            (name: "Car Payment", amount: 450.00, category: BillCategory.transportation.rawValue, issuer: "Auto Finance", firstInstallment: Date().addingTimeInterval(86400 * 9), recurrence: BillRecurrence.monthly),
            
            // Subscriptions and Memberships
            (name: "Gym Membership", amount: 49.99, category: BillCategory.subscriptions.rawValue, issuer: "FitLife", firstInstallment: Date().addingTimeInterval(86400 * 10), recurrence: BillRecurrence.monthly),
            (name: "Streaming Services", amount: 29.99, category: BillCategory.subscriptions.rawValue, issuer: "StreamCo", firstInstallment: Date().addingTimeInterval(86400 * 11), recurrence: BillRecurrence.monthly),
            
            // Additional Bills
            (name: "Life Insurance", amount: 75.00, category: BillCategory.insurance.rawValue, issuer: "LifeGuard", firstInstallment: Date().addingTimeInterval(86400 * 12), recurrence: BillRecurrence.monthly),
            (name: "Home Insurance", amount: 120.00, category: BillCategory.insurance.rawValue, issuer: "HomeShield", firstInstallment: Date().addingTimeInterval(86400 * 13), recurrence: BillRecurrence.monthly),
            (name: "Student Loan", amount: 300.00, category: BillCategory.debt.rawValue, issuer: "EduFinance", firstInstallment: Date().addingTimeInterval(86400 * 14), recurrence: BillRecurrence.monthly),
            (name: "Credit Card", amount: 200.00, category: BillCategory.debt.rawValue, issuer: "CreditCo", firstInstallment: Date().addingTimeInterval(86400 * 15), recurrence: BillRecurrence.monthly),
            (name: "Property Tax", amount: 250.00, category: BillCategory.taxes.rawValue, issuer: "City Hall", firstInstallment: Date().addingTimeInterval(86400 * 16), recurrence: BillRecurrence.quarterly),
            
            // Shared Bills
            (name: "Shared Rent", amount: 2400.00, category: BillCategory.housing.rawValue, issuer: "Landlord Co", firstInstallment: Date().addingTimeInterval(86400 * 5), recurrence: BillRecurrence.monthly),
            (name: "Shared Internet", amount: 79.99, category: BillCategory.internet.rawValue, issuer: "FiberNet", firstInstallment: Date().addingTimeInterval(86400 * 4), recurrence: BillRecurrence.monthly),
            (name: "Shared Utilities", amount: 150.00, category: BillCategory.utilities.rawValue, issuer: "Power Co", firstInstallment: Date().addingTimeInterval(86400 * 3), recurrence: BillRecurrence.monthly)
        ]
        
        for billInfo in sampleBills {
            var currentDate = billInfo.firstInstallment
            for _ in 0..<maxMonthsAhead {
                let bill = Bill(
                    name: billInfo.name,
                    amount: billInfo.amount,
                    category: billInfo.category,
                    issuer: billInfo.issuer,
                    firstInstallment: currentDate,
                    recurrence: billInfo.recurrence.rawValue,
                    isShared: billInfo.name.hasPrefix("Shared"),
                    numberOfShares: billInfo.name.hasPrefix("Shared") ? 2 : 1
                )
                bill.user = user
                user.bills?.append(bill)
                currentDate = billInfo.recurrence.nextDueDate(from: currentDate)
            }
        }
    }
    
    private static func createSampleBudgets(for user: User) {
        // Create bill budgets
        let billBudgets = [
            BillBudget(category: BillCategory.housing.rawValue, amount: 1200.00, dueDate: Date().addingTimeInterval(86400 * 5)),
            BillBudget(category: BillCategory.utilities.rawValue, amount: 250.00, dueDate: Date().addingTimeInterval(86400 * 3)),
            BillBudget(category: BillCategory.insurance.rawValue, amount: 200.00, dueDate: Date().addingTimeInterval(86400 * 7)),
            BillBudget(category: BillCategory.subscriptions.rawValue, amount: 100.00, dueDate: Date().addingTimeInterval(86400 * 4)),
            BillBudget(category: BillCategory.debt.rawValue, amount: 500.00, dueDate: Date().addingTimeInterval(86400 * 6)),
            BillBudget(category: BillCategory.taxes.rawValue, amount: 250.00, dueDate: Date().addingTimeInterval(86400 * 8))
        ]
        
        for budget in billBudgets {
            budget.user = user
            user.billBudgets?.append(budget)
        }
        
        // Create transaction budgets
        let transactionBudgets = [
            TransactionBudget(category: TransactionCategory.groceries.rawValue, limit: 400.00, period: .monthly),
            TransactionBudget(category: TransactionCategory.diningOut.rawValue, limit: 200.00, period: .monthly),
            TransactionBudget(category: TransactionCategory.movies.rawValue, limit: 150.00, period: .monthly),
            TransactionBudget(category: TransactionCategory.hair.rawValue, limit: 100.00, period: .monthly),
            TransactionBudget(category: TransactionCategory.taxi.rawValue, limit: 100.00, period: .weekly),
            TransactionBudget(category: TransactionCategory.travel.rawValue, limit: 2000.00, period: .yearly),
            TransactionBudget(category: TransactionCategory.shoes.rawValue, limit: 300.00, period: .yearly),
            TransactionBudget(category: TransactionCategory.pharmacy.rawValue, limit: 200.00, period: .monthly),
            TransactionBudget(category: TransactionCategory.electronics.rawValue, limit: 1500.00, period: .yearly),
            TransactionBudget(category: TransactionCategory.clothing.rawValue, limit: 500.00, period: .monthly),
            TransactionBudget(category: TransactionCategory.entertainment.rawValue, limit: 100.00, period: .monthly),
            TransactionBudget(category: TransactionCategory.personalCare.rawValue, limit: 150.00, period: .monthly),
            TransactionBudget(category: TransactionCategory.fitness.rawValue, limit: 100.00, period: .monthly),
            TransactionBudget(category: TransactionCategory.gifts.rawValue, limit: 200.00, period: .monthly),
            TransactionBudget(category: TransactionCategory.petSupplies.rawValue, limit: 100.00, period: .monthly)
        ]
        
        for budget in transactionBudgets {
            budget.user = user
            user.transactionBudgets?.append(budget)
        }
    }
} 
