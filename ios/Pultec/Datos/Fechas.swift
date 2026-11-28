import Foundation

/// Fechas y números como los guarda la base: días `yyyy-MM-dd`, instantes ISO 8601.
enum Fechas {
    static var hoy: Date { Calendar.current.startOfDay(for: Date()) }

    private static let formatoDia: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoSinFraccion: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func dia(_ valor: Any?) -> Date? {
        guard let s = valor as? String, !s.isEmpty else { return nil }
        return formatoDia.date(from: String(s.prefix(10)))
    }

    static func texto(_ d: Date) -> String { formatoDia.string(from: d) }

    static func instante(_ valor: Any?) -> Date? {
        guard let s = valor as? String, !s.isEmpty else { return nil }
        if let d = iso.date(from: s) ?? isoSinFraccion.date(from: s) { return d }
        // Postgres devuelve «2026-11-28T08:47:12.123456+00:00»: recorta a milisegundos.
        if let punto = s.firstIndex(of: "."), let fin = s[punto...].firstIndex(where: { $0 == "+" || $0 == "Z" || $0 == "-" }) {
            let fraccion = s[s.index(after: punto)..<fin].prefix(3)
            return iso.date(from: s[..<punto] + "." + fraccion + s[fin...])
        }
        return nil
    }

    static func iso(_ d: Date) -> String { iso.string(from: d) }

    static func numero(_ valor: Any?) -> Double? {
        if let n = valor as? NSNumber { return n.doubleValue }
        if let s = valor as? String { return Double(s) }
        return nil
    }

    /// 480 → «08:00».
    static func hora(_ minutos: Int) -> String {
        String(format: "%02d:%02d", (minutos / 60) % 24, minutos % 60)
    }

    static func dias(desde a: Date, hasta b: Date) -> Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: a),
                                        to: Calendar.current.startOfDay(for: b)).day ?? 0
    }

    static func mas(_ d: Date, dias: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: dias, to: d) ?? d
    }

    /// «hoy», «mañana», «hace 3 días», «en 12 días».
    static func relativo(_ d: Date) -> String {
        let n = dias(desde: hoy, hasta: d)
        switch n {
        case 0: return String(localized: "hoy")
        case 1: return String(localized: "mañana")
        case -1: return String(localized: "ayer")
        case ..<0: return String(localized: "hace \(-n) días")
        default: return String(localized: "en \(n) días")
        }
    }

    /// Primera letra en mayúscula («En 27 días»).
    static func frase(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    /// «4 may».
    static func dm(_ d: Date) -> String { d.formatted(.dateTime.day().month(.abbreviated)) }
    static func corta(_ d: Date) -> String { d.formatted(.dateTime.day().month(.twoDigits).year()) }
    static func larga(_ d: Date) -> String { d.formatted(.dateTime.weekday(.wide).day().month(.wide)) }
}
