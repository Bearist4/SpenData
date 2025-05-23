import SwiftUI
import AuthenticationServices
import SwiftData

struct WelcomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @State private var isAuthenticated = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if let existingUser = users.first {
                if Calendar.current.isDateInToday(existingUser.lastLoginDate) {
                    ContentView()
                } else {
                    welcomeContent
                }
            } else {
                welcomeContent
            }
        }
        .onAppear {
            if let existingUser = users.first {
                Task {
                    await handleExistingUser(existingUser)
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private func handleExistingUser(_ user: User) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load secure data
            try await user.loadSecureData()
            
            // Update last login date
            user.updateLastLoginDate()
            
            // Save changes
            try modelContext.save()
            
            isAuthenticated = true
        } catch {
            errorMessage = "Failed to load user data: \(error.localizedDescription)"
        }
    }
    
    private var welcomeContent: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "dollarsign.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundStyle(.blue)
            
            Text("Welcome to SpenData")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Track your expenses with ease")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            VStack(spacing: 16) {
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        Task {
                            await handleSignInWithApple(result)
                        }
                    }
                )
                .frame(height: 50)
                .cornerRadius(8)
                .disabled(isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .fullScreenCover(isPresented: $isAuthenticated) {
            ContentView()
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }
    
    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        defer { isLoading = false }
        
        switch result {
        case .success(let authResults):
            if let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential {
                // Create or update user in SwiftData
                let userId = appleIDCredential.user
                let email = appleIDCredential.email ?? ""
                let name = [appleIDCredential.fullName?.givenName, appleIDCredential.fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                let user = User(id: userId, email: email, name: name)
                modelContext.insert(user)
                
                do {
                    try modelContext.save()
                    
                    // Save user data securely
                    try await user.saveSecureData()
                    
                    isAuthenticated = true
                } catch {
                    errorMessage = "Failed to save user data: \(error.localizedDescription)"
                }
            }
        case .failure(let error):
            errorMessage = "Authorization failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    WelcomeView()
        .modelContainer(for: User.self)
} 