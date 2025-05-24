import SwiftUI
import SwiftData

struct AddTransactionBudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]

    @State private var category = TransactionCategory.groceries
    @State private var limit = ""
    @State private var period = BudgetPeriod.monthly

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $category) {
                    ForEach(TransactionCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }

                TextField("Limit", text: $limit)
                    .keyboardType(.decimalPad)

                Picker("Period", selection: $period) {
                    Text("Weekly").tag(BudgetPeriod.weekly)
                    Text("Monthly").tag(BudgetPeriod.monthly)
                    Text("Yearly").tag(BudgetPeriod.yearly)
                }
            }
            .navigationTitle("New Category Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTransactionBudget()
                    }
                }
            }
        }
    }

    private func addTransactionBudget() {
        guard let limitValue = FormattingUtils.parseNumber(limit), limitValue > 0 else { return }
        guard let user = users.first else { return }

        let budget = TransactionBudget(
            category: category.rawValue,
            limit: limitValue,
            period: period
        )
        
        // Associate budget with user
        budget.user = user
        user.transactionBudgets?.append(budget)

        modelContext.insert(budget)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddTransactionBudgetView()
        .modelContainer(PreviewData.createPreviewContainer())
} 