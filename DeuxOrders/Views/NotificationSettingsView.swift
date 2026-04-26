import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var isRequesting = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: statusIcon)
                        .foregroundColor(statusColor)
                        .frame(width: 30, height: 30)
                        .background(statusColor.opacity(0.12))
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(statusTitle)
                            .font(.subheadline.weight(.semibold))
                        Text(statusSubtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Lembretes locais") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Pedidos de hoje")
                            .font(.subheadline.weight(.medium))
                        Text("08:00")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(DSColor.warn)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Pedidos de amanhã")
                            .font(.subheadline.weight(.medium))
                        Text("15:00")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(DSColor.brand)
                }
            }

            Section {
                if status == .notDetermined {
                    Button {
                        Task { await requestPermission() }
                    } label: {
                        HStack {
                            Spacer()
                            if isRequesting {
                                ProgressView()
                            } else {
                                Text("Permitir notificações")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isRequesting)
                } else if status == .denied {
                    Text("Ative as notificações nos Ajustes do iOS para receber lembretes locais.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Button(role: .destructive) {
                        NotificationService.shared.cancelScheduledReminders()
                    } label: {
                        Label("Cancelar lembretes agendados", systemImage: "bell.slash")
                    }
                }
            } footer: {
                Text("Os lembretes são locais e usam os pedidos já carregados no app. Nenhum endpoint de Web Push é usado no iOS.")
            }

            Section {
                Button(role: .destructive) {
                    AppSession.logout()
                } label: {
                    Label("Sair", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Notificações")
        .task { await refreshStatus() }
    }

    private var statusTitle: String {
        switch status {
        case .notDetermined:
            return "Não configurado"
        case .denied:
            return "Bloqueado"
        case .authorized, .provisional, .ephemeral:
            return "Autorizado"
        @unknown default:
            return "Desconhecido"
        }
    }

    private var statusSubtitle: String {
        switch status {
        case .notDetermined:
            return "O app ainda não pediu permissão."
        case .denied:
            return "O iOS negou notificações para este app."
        case .authorized, .provisional, .ephemeral:
            return "Lembretes serão atualizados após carregar pedidos."
        @unknown default:
            return "Verifique os Ajustes do iOS."
        }
    }

    private var statusIcon: String {
        switch status {
        case .notDetermined:
            return "bell.badge"
        case .denied:
            return "bell.slash.fill"
        case .authorized, .provisional, .ephemeral:
            return "bell.fill"
        @unknown default:
            return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch status {
        case .notDetermined:
            return DSColor.warn
        case .denied:
            return DSColor.destructive
        case .authorized, .provisional, .ephemeral:
            return DSColor.ok
        @unknown default:
            return DSColor.foregroundSoft
        }
    }

    private func refreshStatus() async {
        status = await NotificationService.shared.authorizationStatus()
    }

    private func requestPermission() async {
        isRequesting = true
        _ = await NotificationService.shared.requestAuthorization()
        await refreshStatus()
        isRequesting = false
    }
}
