import AppIntents
import SwiftData

@available(iOS 16.0, *)
struct LogTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Transaction"
    static var description: LocalizedStringResource = "Log a transaction from Apple Wallet"
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Transaction Title", description: "The name or title of the transaction")
    var transactionTitle: String
    
    @Parameter(title: "Amount", description: "The amount of the transaction")
    var amount: Double
    
    @Parameter(title: "Category", description: "The category of the transaction", default: "Uncategorized")
    var category: String
    
    @Parameter(title: "Date", description: "The date of the transaction", default: .now)
    var date: Date
    
    @Parameter(title: "Notes", description: "Additional notes about the transaction", default: "")
    var notes: String
    
    func perform() async throws -> some IntentResult {
        let modelContainer = try await ModelContainer(for: Transaction.self)
        let context = await modelContainer.mainContext
        
        let transaction = Transaction(
            name: transactionTitle,
            amount: abs(amount), // Store as positive value
            category: category,
            date: date,
            notes: notes.isEmpty ? nil : notes
        )
        
        await context.insert(transaction)
        try await context.save()
        
        return .result()
    }
}

@available(iOS 16.0, *)
extension LogTransactionIntent {
    static var parameterSummary: some ParameterSummary {
        Summary("Log transaction '\(\.$transactionTitle)' for \(\.$amount) in category \(\.$category)")
    }
} 