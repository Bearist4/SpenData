import SwiftUI
import SwiftData

struct AddIncomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Environment(\.dismiss) private var dismiss
    
    @State private var category: IncomeCategory = .salary
    @State private var issuer = ""
    @State private var frequency: IncomeFrequency = .monthly
    @State private var paymentTiming: PaymentTiming = .beginningOfMonth
    @State private var firstPayment = Date()
    @State private var amount = ""
    @State private var notes = ""
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                incomeDetailsSection
                amountSection
                notesSection
                addButtonSection
            }
            .navigationTitle("Add Income")
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var incomeDetailsSection: some View {
        Section("Income Details") {
            categoryPicker
            issuerField
            frequencyPicker
            paymentTimingPicker
            firstPaymentPicker
        }
    }
    
    private var categoryPicker: some View {
        Picker("Category", selection: $category) {
            ForEach(IncomeCategory.allCases, id: \.self) { category in
                Text(category.rawValue)
                    .tag(category)
            }
        }
    }
    
    private var issuerField: some View {
        TextField("Issuer", text: $issuer)
    }
    
    private var frequencyPicker: some View {
        Picker("Frequency", selection: $frequency) {
            ForEach(IncomeFrequency.allCases, id: \.self) { frequency in
                Text(frequency.rawValue)
                    .tag(frequency)
            }
        }
    }
    
    private var paymentTimingPicker: some View {
        Picker("Payment Timing", selection: $paymentTiming) {
            ForEach(PaymentTiming.allCases, id: \.self) { timing in
                Text(timing.rawValue)
                    .tag(timing)
            }
        }
    }
    
    private var firstPaymentPicker: some View {
        DatePicker("First Payment", selection: $firstPayment, displayedComponents: .date)
    }
    
    private var amountSection: some View {
        Section("Amount") {
            TextField("Amount", text: $amount)
                .keyboardType(.decimalPad)
        }
    }
    
    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $notes)
                .frame(minHeight: 100)
        }
    }
    
    private var addButtonSection: some View {
        Section {
            Button("Add Income") {
                addIncome()
            }
            .frame(maxWidth: .infinity)
            .disabled(amount.isEmpty)
        }
    }
    
    private func addIncome() {
        guard let amountValue = FormattingUtils.parseNumber(amount) else {
            alertMessage = "Please enter a valid amount"
            showingAlert = true
            return
        }
        
        guard let user = users.first else {
            alertMessage = "No user found"
            showingAlert = true
            return
        }
        
        let income = Income(
            name: category.rawValue,
            amount: amountValue,
            category: category.rawValue,
            issuer: issuer,
            firstPayment: firstPayment,
            frequency: frequency.rawValue,
            paymentTiming: paymentTiming.rawValue,
            notes: notes.isEmpty ? nil : notes
        )
        
        income.user = user
        user.incomes?.append(income)
        modelContext.insert(income)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to save income: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

#Preview {
    AddIncomeView()
        .modelContainer(PreviewData.createPreviewContainer())
} 