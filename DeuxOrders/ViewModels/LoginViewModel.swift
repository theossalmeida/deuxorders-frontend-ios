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

    init() {
        isAuthenticated = KeychainService.load(forKey: AppEnvironment.tokenKey) != nil
    }
    
    func login() async {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else {
            errorMessage = "Preencha todos os campos."
            return
        }

        guard email.contains("@"), email.contains(".") else {
            errorMessage = "Informe um email válido."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let credentials = UserCredentials(email: email, password: password)
            let token = try await authService.login(credentials: credentials)
            
            KeychainService.save(token, forKey: AppEnvironment.tokenKey)
            
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
