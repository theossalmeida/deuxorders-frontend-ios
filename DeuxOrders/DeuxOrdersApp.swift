import SwiftUI

@main
struct DeuxOrdersApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView()
                .preferredColorScheme(.light)
                .task {
                    await NotificationService.shared.requestAuthorization()
                }
        }
    }
}
