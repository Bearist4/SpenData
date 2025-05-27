import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var amount = ""
    @State private var category = TransactionCategory.uncategorized.rawValue
    @State private var date = Date()
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    Picker("Category", selection: $category) {
                        ForEach(TransactionCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category.rawValue)
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTransaction()
                    }
                    .disabled(name.isEmpty || amount.isEmpty)
                }
            }
        }
    }
    
    private func addTransaction() {
        guard let amountValue = FormattingUtils.parseNumber(amount) else { return }
        
        let transaction = Transaction(
            name: name,
            amount: -abs(amountValue),
            category: category,
            date: date,
            notes: notes.isEmpty ? nil : notes
        )
        
        modelContext.insert(transaction)
        
        // Check if a budget exists for this category
        let predicate = #Predicate<TransactionBudget> { budget in
            budget.category == category
        }
        let existingBudgets = try? modelContext.fetch(FetchDescriptor<TransactionBudget>(predicate: predicate))
        
        // If no budget exists, create one without a limit
        if existingBudgets?.isEmpty ?? true {
            let budget = TransactionBudget(
                category: category,
                limit: 0, // No limit initially
                period: .monthly // Default to monthly
            )
            
            // Get the current user and associate the budget
            if let user = try? modelContext.fetch(FetchDescriptor<User>()).first {
                budget.user = user
                user.transactionBudgets?.append(budget)
            }
            
            modelContext.insert(budget)
            try? modelContext.save()
        }
        
        dismiss()
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(PreviewData.createPreviewContainer())
} 
