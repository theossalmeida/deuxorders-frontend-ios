import Foundation
import Combine

@MainActor
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    
    private let authService = AuthService()
    
    func login() async {
        guard !email.isEmpty && !password.isEmpty else {
            errorMessage = "Preencha todos os campos."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let credentials = UserCredentials(email: email, password: password)
            let token = try await authService.login(credentials: credentials)
            
            KeychainService.save(token, forKey: "user_token")
            
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
