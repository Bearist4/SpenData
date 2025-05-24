import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                if let user = users.first {
                    Section {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(user.name ?? "Not set")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(user.email ?? "Not set")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Device ID")
                            Spacer()
                            Text(user.deviceIdentifier)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section {
                    NavigationLink(destination: BillsListView()) {
                        Label("Bills", systemImage: "list.bullet")
                    }
                }
                
                Section {
                    Button("Sign Out", role: .destructive) {
                        showingSignOutConfirmation = true
                    }
                }
                
                Section {
                    Button("Delete Account", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
            .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    private func deleteAccount() {
        guard let user = users.first else { return }
        
        // Delete all bills
        if let bills = user.bills {
            for bill in bills {
                modelContext.delete(bill)
            }
        }
        
        // Delete user
        modelContext.delete(user)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error deleting account: \(error)")
        }
    }
    
    private func signOut() {
        guard let user = users.first else { return }
        
        // Update last login date
        user.updateLastLoginDate()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error signing out: \(error)")
        }
    }
}

struct BillsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var bills: [Bill]
    @State private var showingAddBill = false
    
    private var billsByCategory: [String: [Bill]] {
        Dictionary(grouping: bills) { $0.category ?? "Uncategorized" }
    }
    
    var body: some View {
        List {
            ForEach(Array(billsByCategory.keys.sorted()), id: \.self) { category in
                NavigationLink(destination: CategoryBillsView(category: category)) {
                    HStack {
                        Circle()
                            .fill(BillCategory(rawValue: category)?.color ?? .gray)
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading) {
                            Text(category)
                                .font(.headline)
                            Text("\(billsByCategory[category]?.count ?? 0) bills")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let total = billsByCategory[category]?.reduce(0, { $0 + ($1.amount ?? 0) }) {
                            Text(FormattingUtils.formatCurrency(total))
                                .font(.headline)
                        }
                    }
                }
            }
        }
        .navigationTitle("Bills")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddBill = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddBill) {
            AddBillView()
        }
    }
}

struct CategoryBillsView: View {
    let category: String
    @Query private var bills: [Bill]
    @Environment(\.modelContext) private var modelContext
    
    init(category: String) {
        self.category = category
        let predicate = #Predicate<Bill> { bill in
            bill.category == category
        }
        _bills = Query(filter: predicate)
    }
    
    var body: some View {
        List {
            ForEach(bills) { bill in
                NavigationLink(destination: BillDetailView(bill: bill)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(bill.name ?? "Unnamed Bill")
                                .font(.headline)
                            Spacer()
                            Text(FormattingUtils.formatCurrency(bill.amount ?? 0))
                                .font(.headline)
                        }
                        
                        HStack {
                            Text(bill.issuer ?? "Unknown Issuer")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Next due: \(bill.firstInstallment, style: .date)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if bill.isShared {
                            Text("Shared: \(bill.numberOfShares) people")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteBills)
        }
        .navigationTitle(category)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
    
    private func deleteBills(at offsets: IndexSet) {
        for index in offsets {
            let bill = bills[index]
            modelContext.delete(bill)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting bills: \(error)")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [User.self, Bill.self])
} 