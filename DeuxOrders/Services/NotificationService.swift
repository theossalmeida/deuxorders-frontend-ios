import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestAuthorization() async {
        do {
            try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("❌ Erro ao pedir permissão de notificação: \(error)")
        }
    }

    func scheduleNotifications(orders: [Order]) async {
        let center = UNUserNotificationCenter.current()

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            print("⚠️ Notificações não autorizadas: \(settings.authorizationStatus.rawValue)")
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: ["morning-daily", "afternoon-daily"])

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let todayPending = orders.filter {
            calendar.isDate($0.deliveryDate, inSameDayAs: today) && $0.status != .completed
        }

        let tomorrowPending = orders.filter {
            calendar.isDate($0.deliveryDate, inSameDayAs: tomorrow) && $0.status != .completed
        }

        let todayCount = todayPending.count
        let tomorrowCount = tomorrowPending.count

        await schedule(
            id: "morning-daily",
            title: "Bom dia! ☀️",
            body: todayCount == 0
                ? "Nenhum pedido para entregar hoje."
                : todayCount == 1
                    ? "Você tem 1 pedido para entregar hoje."
                    : "Você tem \(todayCount) pedidos para entregar hoje.",
            hour: 8,
            minute: 0
        )

        await schedule(
            id: "afternoon-daily",
            title: "Lembrete de amanhã 📦",
            body: tomorrowCount == 0
                ? "Nenhum pedido para entregar amanhã."
                : tomorrowCount == 1
                    ? "Você tem 1 pedido para entregar amanhã."
                    : "Você tem \(tomorrowCount) pedidos para entregar amanhã.",
            hour: 15,
            minute: 0
        )
    }

    private func schedule(id: String, title: String, body: String, hour: Int, minute: Int) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("❌ Erro ao agendar notificação '\(id)': \(error)")
        }
    }
}
