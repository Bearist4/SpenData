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

#Preview {
    SettingsView()
        .modelContainer(for: [User.self, Bill.self])
} 