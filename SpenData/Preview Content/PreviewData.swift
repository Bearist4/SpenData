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
            Transaction(name: "Grocery Shopping", amount: 45.99, category: TransactionCategory.groceries.rawValue, date: Date().addingTimeInterval(-86400), notes: "Grocery shopping"),
            Transaction(name: "Lunch with Team", amount: 25.50, category: TransactionCategory.diningOut.rawValue, date: Date().addingTimeInterval(-172800), notes: "Lunch with Team"),
            Transaction(name: "New Shoes", amount: 89.99, category: TransactionCategory.shoes.rawValue, date: Date().addingTimeInterval(-259200), notes: "New Shoes"),
            Transaction(name: "Uber Ride", amount: 15.00, category: TransactionCategory.taxi.rawValue, date: Date().addingTimeInterval(-345600), notes: "Uber Ride"),
            Transaction(name: "Movie Tickets", amount: 24.99, category: TransactionCategory.movies.rawValue, date: Date().addingTimeInterval(-432000), notes: "Movie Tickets"),
            Transaction(name: "Pharmacy", amount: 35.75, category: TransactionCategory.pharmacy.rawValue, date: Date().addingTimeInterval(-518400), notes: "Pharmacy"),
            Transaction(name: "Haircut", amount: 30.00, category: TransactionCategory.hair.rawValue, date: Date().addingTimeInterval(-604800), notes: "Haircut"),
            Transaction(name: "Freelance Work", amount: 150.00, category: TransactionCategory.miscellaneous.rawValue, date: Date().addingTimeInterval(-691200), notes: "Freelance Work"),
            Transaction(name: "Salary", amount: 2500.00, category: TransactionCategory.miscellaneous.rawValue, date: Date().addingTimeInterval(-777600), notes: "Salary")
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
            (name: "Rent", amount: 1200.00, category: BillCategory.housing.rawValue, issuer: "Landlord Co", firstInstallment: Date().addingTimeInterval(86400 * 5), recurrence: BillRecurrence.monthly),
            (name: "Electricity", amount: 150.00, category: BillCategory.utilities.rawValue, issuer: "Power Co", firstInstallment: Date().addingTimeInterval(86400 * 3), recurrence: BillRecurrence.monthly),
            (name: "Water", amount: 80.00, category: BillCategory.utilities.rawValue, issuer: "Water Co", firstInstallment: Date().addingTimeInterval(86400 * 2), recurrence: BillRecurrence.monthly),
            (name: "Car Insurance", amount: 200.00, category: BillCategory.insurance.rawValue, issuer: "SafeDrive", firstInstallment: Date().addingTimeInterval(86400 * 7), recurrence: BillRecurrence.monthly)
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
                    isShared: false,
                    numberOfShares: 1
                )
                bill.user = user
                user.bills?.append(bill)
                // Move to next recurrence
                currentDate = billInfo.recurrence.nextDueDate(from: currentDate)
            }
        }
    }
    
    private static func createSampleBudgets(for user: User) {
        // Create bill budgets
        let billBudgets = [
            BillBudget(category: BillCategory.housing.rawValue, amount: 1200.00, dueDate: Date().addingTimeInterval(86400 * 5)),
            BillBudget(category: BillCategory.utilities.rawValue, amount: 250.00, dueDate: Date().addingTimeInterval(86400 * 3)),
            BillBudget(category: BillCategory.insurance.rawValue, amount: 200.00, dueDate: Date().addingTimeInterval(86400 * 7))
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
            TransactionBudget(category: TransactionCategory.travel.rawValue, limit: 2000.00, period: .yearly)
        ]
        
        for budget in transactionBudgets {
            budget.user = user
            user.transactionBudgets?.append(budget)
        }
    }
} 
