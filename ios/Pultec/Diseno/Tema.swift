import SwiftUI

/// Colores con nombre de un tema: fondo en degradado, superficie de tarjetas,
/// texto, secundario y acento. Las vistas nunca usan colores sueltos: leen la
/// paleta del entorno (`@Environment(\.paleta)`).
struct Paleta: Equatable {
    let fondo: Color
    let fondoFin: Color
    let superficie: Color
    let texto: Color
    let secundario: Color
    let acento: Color
    let esOscuro: Bool

    var degradado: LinearGradient {
        LinearGradient(colors: [fondo, fondoFin], startPoint: .top, endPoint: .bottom)
    }

    /// Claro y oscuro usan el color de acento de la app (AccentColor en Assets).
    static let clara = Paleta(fondo: .white, fondoFin: .white,
                              superficie: .white, texto: .black, secundario: Color(hex: 0x6C6C70),
                              acento: .accentColor, esOscuro: false)
    static let oscura = Paleta(fondo: .black, fondoFin: .black,
                               superficie: .black, texto: .white, secundario: Color(hex: 0x98989F),
                               acento: .accentColor, esOscuro: true)

    /// Temas de color: fondo, fin del degradado, superficie, texto, secundario, acento.
    init(_ fondo: UInt32, _ fondoFin: UInt32, _ superficie: UInt32,
         _ texto: UInt32, _ secundario: UInt32, _ acento: UInt32, oscuro: Bool) {
        self.init(fondo: Color(hex: fondo), fondoFin: Color(hex: fondoFin), superficie: Color(hex: superficie),
                  texto: Color(hex: texto), secundario: Color(hex: secundario), acento: Color(hex: acento),
                  esOscuro: oscuro)
    }

    init(fondo: Color, fondoFin: Color, superficie: Color, texto: Color,
         secundario: Color, acento: Color, esOscuro: Bool) {
        self.fondo = fondo
        self.fondoFin = fondoFin
        self.superficie = superficie
        self.texto = texto
        self.secundario = secundario
        self.acento = acento
        self.esOscuro = esOscuro
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255,
                  opacity: 1)
    }
}

extension EnvironmentValues {
    @Entry var paleta: Paleta = .clara
}

/// Temas de Pultec: como la web, claro u oscuro (o lo que diga el sistema).
enum Tema: String, CaseIterable, Identifiable {
    case sistema, claro, oscuro

    var id: String { rawValue }

    var nombre: LocalizedStringKey {
        switch self {
        case .sistema: "Sistema"
        case .claro: "Claro"
        case .oscuro: "Oscuro"
        }
    }

    /// nil = sigue al sistema.
    var esquema: ColorScheme? {
        switch self {
        case .sistema: nil
        case .claro: .light
        case .oscuro: .dark
        }
    }

    func paleta(_ esquemaSistema: ColorScheme) -> Paleta {
        switch self {
        case .sistema: esquemaSistema == .dark ? .oscura : .clara
        case .claro: .clara
        case .oscuro: .oscura
        }
    }
}

extension Font {
    /// Texto de interfaz: fuente del sistema con el diseño de la marca.
    static func app(_ estilo: Font.TextStyle, _ peso: Font.Weight = .regular) -> Font {
        .system(estilo, design: Marca.disenoSistema, weight: peso)
    }
}
