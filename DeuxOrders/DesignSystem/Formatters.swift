import Foundation

enum Formatters {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        ISO8601DateFormatter()
    }()

    /// Formats integer cents as BRL currency string: 1550 → "R$ 15,50"
    static func brl(_ cents: Int) -> String {
        currency.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "R$ 0,00"
    }

    /// Parses a BRL-formatted string to integer cents: "15,50" → 1550, "15.50" → 1550
    static func parseCents(_ text: String) -> Int? {
        let cleaned = text.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value >= 0 else { return nil }
        return Int(round(value * 100))
    }

    /// Formats a Date to a short localized pt-BR string
    static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateStyle = .medium
        return f.string(from: date)
    }

    /// Formats a Date to "HH:mm"
    static func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// Relative day label: "Hoje", "Amanhã", "Ontem", or short date
    static func relativeDay(_ date: Date) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let target = cal.startOfDay(for: date)
        let diff = cal.dateComponents([.day], from: today, to: target).day ?? 0

        switch diff {
        case 0: return "Hoje"
        case 1: return "Amanhã"
        case -1: return "Ontem"
        default: return shortDate(date)
        }
    }
}

enum DateRangePreset: String, CaseIterable {
    case today = "Hoje"
    case week = "Semana"
    case month = "Mês"
    case custom = "Período"

    func dates() -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch self {
        case .today:
            return (today, today)
        case .week:
            guard let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else { return nil }
            return (start, today)
        case .month:
            guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else { return nil }
            return (start, today)
        case .custom:
            return nil
        }
    }
}
