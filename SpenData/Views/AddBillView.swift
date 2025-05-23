import SwiftUI
import SwiftData

struct AddBillView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var user: [User]
    @Environment(\.dismiss) private var dismiss
    
    @State private var category: BillCategory = .uncategorized
    @State private var name = ""
    @State private var issuer = ""
    @State private var recurrence: BillRecurrence = .monthly
    @State private var customRecurrenceDays = ""
    @State private var firstInstallment = Date()
    @State private var isShared = false
    @State private var numberOfShares = 2
    @State private var amount = ""
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                billDetailsSection
                amountSection
                addButtonSection
            }
            .navigationTitle("Add Bill")
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var billDetailsSection: some View {
        Section("Bill Details") {
            categoryPicker
            nameField
            issuerField
            recurrencePicker
            customRecurrenceField
            firstInstallmentPicker
        }
    }
    
    private var categoryPicker: some View {
        Picker("Category", selection: $category) {
            ForEach(BillCategory.allCases, id: \.self) { category in
                Text(category.rawValue)
                    .tag(category)
            }
        }
    }
    
    private var nameField: some View {
        TextField("Name", text: $name)
    }
    
    private var issuerField: some View {
        TextField("Issuer", text: $issuer)
    }
    
    private var recurrencePicker: some View {
        Picker("Recurrence", selection: $recurrence) {
            ForEach(BillRecurrence.allCases, id: \.self) { recurrence in
                Text(recurrence.rawValue)
                    .tag(recurrence)
            }
        }
    }
    
    private var customRecurrenceField: some View {
        Group {
            if recurrence == .custom {
                TextField("Number of days", text: $customRecurrenceDays)
                    .keyboardType(.numberPad)
            }
        }
    }
    
    private var firstInstallmentPicker: some View {
        DatePicker("First Installment", selection: $firstInstallment, displayedComponents: .date)
    }
    
    private var amountSection: some View {
        Section("Amount") {
            amountField
            sharedBillToggle
            sharedBillStepper
        }
    }
    
    private var amountField: some View {
        TextField("Amount", text: $amount)
            .keyboardType(.decimalPad)
    }
    
    private var sharedBillToggle: some View {
        Toggle("Shared Bill", isOn: $isShared)
    }
    
    private var sharedBillStepper: some View {
        Group {
            if isShared {
                Stepper("Number of shares: \(numberOfShares)", value: $numberOfShares, in: 2...10)
            }
        }
    }
    
    private var addButtonSection: some View {
        Section {
            Button("Add Bill") {
                saveBill()
            }
        }
    }
    
    private func saveBill() {
        guard let currentUser = user.first else {
            alertMessage = "User not found"
            showingAlert = true
            return
        }
        
        guard !name.isEmpty else {
            alertMessage = "Please enter a name"
            showingAlert = true
            return
        }
        
        guard !issuer.isEmpty else {
            alertMessage = "Please enter an issuer"
            showingAlert = true
            return
        }
        
        guard let amountValue = Double(amount) else {
            alertMessage = "Please enter a valid amount"
            showingAlert = true
            return
        }
        
        if recurrence == .custom {
            guard let days = Int(customRecurrenceDays), days > 0 else {
                alertMessage = "Please enter a valid number of days"
                showingAlert = true
                return
            }
        }
        
        let newBill = Bill(
            name: name,
            amount: amountValue,
            category: category.rawValue,
            issuer: issuer,
            firstInstallment: firstInstallment,
            recurrence: recurrence.rawValue,
            isShared: isShared,
            numberOfShares: numberOfShares
        )
        
        modelContext.insert(newBill)
        
        do {
            try modelContext.save()
            
            // Save to secure storage and iCloud
            Task {
                do {
                    try await newBill.saveSecureData()
                    print("✅ Bill successfully saved to secure storage and iCloud")
                    
                    // Update UI on main thread
                    await MainActor.run {
                        // Clear the form
                        name = ""
                        issuer = ""
                        amount = ""
                        category = .uncategorized
                        recurrence = .monthly
                        customRecurrenceDays = ""
                        firstInstallment = Date()
                        isShared = false
                        numberOfShares = 2
                        alertMessage = "Bill added successfully!"
                        showingAlert = true
                    }
                } catch {
                    print("❌ Failed to save bill to secure storage: \(error)")
                    await MainActor.run {
                        alertMessage = "Failed to save bill to secure storage: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
            }
        } catch {
            alertMessage = "Failed to save bill: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

#Preview {
    AddBillView()
        .modelContainer(for: [User.self, Bill.self])
} 