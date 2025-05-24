import SwiftUI

struct TransactionListItem: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.name ?? "")
                    .font(.headline)
                if let category = transaction.category {
                    Text(category)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(FormattingUtils.formatCurrency(abs(transaction.amount)))
                    .font(.headline)
                
                Text(transaction.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    TransactionListItem(transaction: Transaction(
        name: "Grocery Shopping",
        amount: -45.99,
        category: TransactionCategory.groceries.rawValue,
        date: Date()
    ))
} 