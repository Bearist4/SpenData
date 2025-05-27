import AppIntents
import SwiftData

@available(iOS 16.0, *)
struct TestTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Test Transaction"
    static var description: LocalizedStringResource = "Simulate a transaction for testing"
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Merchant Name", description: "The name of the merchant", default: "Test Store")
    var merchantName: String
    
    @Parameter(title: "Amount", description: "The amount of the transaction", default: 19.99)
    var amount: Double
    
    @Parameter(title: "Category", description: "The category of the transaction", default: "Uncategorized")
    var category: String
    
    func perform() async throws -> some IntentResult {
        // Create a test transaction
        let modelContainer = try await ModelContainer(for: Transaction.self)
        let context = await modelContainer.mainContext
        
        let transaction = Transaction(
            name: merchantName,
            amount: -abs(amount),
            category: category,
            date: Date(),
            notes: "Test transaction created via Shortcuts"
        )
        
        await context.insert(transaction)
        try await context.save()
        
        return .result()
    }
}

@available(iOS 16.0, *)
extension TestTransactionIntent {
    static var parameterSummary: some ParameterSummary {
        Summary("Create test transaction at '\(\.$merchantName)' for \(\.$amount)")
    }
} 