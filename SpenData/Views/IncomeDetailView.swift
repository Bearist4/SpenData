import SwiftUI
import SwiftData

struct IncomeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var income: Income
    
    @State private var showingDeleteAlert = false
    @State private var showingEditSheet = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        Form {
            Section(header: Text("Income Details")) {
                LabeledContent("Category", value: income.category ?? "Uncategorized")
                LabeledContent("Issuer", value: income.issuer ?? "Unknown")
                LabeledContent("Amount", value: FormattingUtils.formatCurrency(income.amount))
            }
            
            Section(header: Text("Payment Details")) {
                LabeledContent("Frequency", value: income.frequency ?? "Unknown")
                LabeledContent("Payment Timing", value: income.paymentTiming ?? "Unknown")
                LabeledContent("First Payment", value: dateFormatter.string(from: income.firstPayment))
                LabeledContent("Next Payment", value: dateFormatter.string(from: income.nextPaymentDate))
                LabeledContent("Effective Month", value: dateFormatter.string(from: income.effectiveMonth))
            }
            
            if let notes = income.notes {
                Section(header: Text("Notes")) {
                    Text(notes)
                }
            }
            
            Section {
                Button("Delete Income", role: .destructive) {
                    showingDeleteAlert = true
                }
            }
        }
        .navigationTitle("Income Details")
        .alert("Delete Income", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteIncome()
            }
        } message: {
            Text("Are you sure you want to delete this income? This action cannot be undone.")
        }
        .sheet(isPresented: $showingEditSheet) {
            EditIncomeView(income: income)
        }
    }
    
    private func deleteIncome() {
        if let user = income.user {
            user.incomes?.removeAll { $0.id == income.id }
        }
        modelContext.delete(income)
        dismiss()
    }
}

#Preview {
    IncomeDetailView(income: Income(
        name: "Test Income",
        amount: 1000,
        category: "Salary",
        issuer: "Company",
        firstPayment: Date(),
        frequency: "Monthly",
        paymentTiming: "Beginning of Month"
    ))
    .modelContainer(PreviewData.createPreviewContainer())
} 