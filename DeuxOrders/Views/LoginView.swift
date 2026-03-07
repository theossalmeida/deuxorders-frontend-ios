import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    
    private let brandColor = Color(red: 88/255, green: 22/255, blue: 41/255)
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    brandColor
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        Spacer()
                        
                        headerView(screenWidth: geometry.size.width)
                        
                        VStack(spacing: 20) {
                            TextField("Email", text: $viewModel.email)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .controlSize(.large)
                            
                            SecureField("Senha", text: $viewModel.password)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.large)
                            
                            if let error = viewModel.errorMessage {
                                errorMessageView(message: error)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .frame(width: geometry.size.width * 0.75)
                        .padding(.vertical, 20)
                        
                        Spacer()
                            .frame(height: 20)
                        
                        loginButton(screenWidth: geometry.size.width)
                        
                        Spacer()
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .animation(.spring(), value: viewModel.errorMessage)
            }
            .navigationDestination(isPresented: $viewModel.isAuthenticated) {
                MainTabView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}

// MARK: - Componentes de UI
private extension LoginView {
    
    func headerView(screenWidth: CGFloat) -> some View {
        VStack {
            if let _ = UIImage(named: "logo_escrito") {
                Image("logo_escrito")
                    .resizable()
                    .scaledToFit()
                    .frame(width: screenWidth * 0.95)
            } else {
                VStack {
                    Image(systemName: "briefcase.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80)
                        .foregroundColor(.white)
                    Text("DeuxOrders")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.bottom, 30)
    }
    
    func errorMessageView(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.2))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    func loginButton(screenWidth: CGFloat) -> some View {
        Button(action: handleLogin) {
            Group {
                if viewModel.isLoading {
                    ProgressView().tint(brandColor)
                } else {
                    Text("Entrar")
                        .fontWeight(.bold)
                        .foregroundColor(brandColor)
                }
            }
            .frame(width: screenWidth * 0.40)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
        }
        .disabled(viewModel.isLoading)
    }
    
    func handleLogin() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        Task { await viewModel.login() }
    }
}
