import SwiftUI
import SwiftData

struct EditIncomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var income: Income
    
    @State private var category: IncomeCategory
    @State private var issuer: String
    @State private var frequency: IncomeFrequency
    @State private var paymentTiming: PaymentTiming
    @State private var firstPayment: Date
    @State private var amount: String
    @State private var notes: String
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    init(income: Income) {
        self.income = income
        _category = State(initialValue: IncomeCategory(rawValue: income.category ?? "") ?? .salary)
        _issuer = State(initialValue: income.issuer ?? "")
        _frequency = State(initialValue: IncomeFrequency(rawValue: income.frequency ?? "") ?? .monthly)
        _paymentTiming = State(initialValue: PaymentTiming(rawValue: income.paymentTiming ?? "") ?? .beginningOfMonth)
        _firstPayment = State(initialValue: income.firstPayment)
        _amount = State(initialValue: FormattingUtils.formatCurrency(income.amount))
        _notes = State(initialValue: income.notes ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                incomeDetailsSection
                amountSection
                notesSection
                saveButtonSection
            }
            .navigationTitle("Edit Income")
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
    
    private var saveButtonSection: some View {
        Section {
            Button("Save Changes") {
                saveChanges()
            }
            .frame(maxWidth: .infinity)
            .disabled(amount.isEmpty)
        }
    }
    
    private func saveChanges() {
        guard let amountValue = FormattingUtils.parseNumber(amount) else {
            alertMessage = "Please enter a valid amount"
            showingAlert = true
            return
        }
        
        income.category = category.rawValue
        income.issuer = issuer
        income.frequency = frequency.rawValue
        income.paymentTiming = paymentTiming.rawValue
        income.firstPayment = firstPayment
        income.amount = amountValue
        income.notes = notes.isEmpty ? nil : notes
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to save changes: \(error.localizedDescription)"
            showingAlert = true
        }
    }
} 