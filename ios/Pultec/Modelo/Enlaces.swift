import Foundation

/// Enlaces públicos de la app. App Store Connect exige URL de privacidad y de
/// soporte: cámbialos por los reales antes de publicar.
enum Enlaces {
    static let privacidad = URL(string: "https://example.com/privacy")!
    static let soporte = URL(string: "https://example.com/support")!
    /// Cambia el id cuando la app exista en App Store Connect.
    static let appStore = URL(string: "https://apps.apple.com/app/id0000000000")!
}

extension Bundle {
    /// "1.0 (1)": versión y build, para Ajustes.
    var versionCompleta: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
