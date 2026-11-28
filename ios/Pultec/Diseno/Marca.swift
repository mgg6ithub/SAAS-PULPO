import SwiftUI
import UIKit
import CoreText

/// Identidad de la app: fuente de marca y logo. La fuente propia es el primer
/// .ttf/.otf que haya dentro de la carpeta de la app (Recursos/Fuentes); el
/// logo, la imagen "Logo" de Assets. Si no hay, se usa la fuente del sistema
/// con `disenoSistema` y solo el nombre de la app.
enum Marca {
    static let nombre = "Pultec"
    /// Diseño de la fuente del sistema: .default, .rounded, .serif o .monospaced.
    static let disenoSistema: Font.Design = .default
    /// Nombre PostScript de la fuente propia; se averigua al registrarla.
    private(set) static var fuente: String?

    /// Registra las fuentes incluidas en la app sin tocar Info.plist.
    static func registrarFuentes() {
        let urls = ["ttf", "otf"].flatMap { Bundle.main.urls(forResourcesWithExtension: $0, subdirectory: nil) ?? [] }
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            if fuente == nil,
               let descriptores = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
               let primero = descriptores.first,
               let nombre = CTFontDescriptorCopyAttribute(primero, kCTFontNameAttribute) as? String {
                fuente = nombre
            }
        }
    }

    /// Fuente de marca para logotipo y títulos grandes. `fijo` no crece con el
    /// tamaño de texto del sistema (solo para el logotipo).
    static func titulo(_ tamano: CGFloat, fijo: Bool = false) -> Font {
        if let fuente {
            return fijo ? .custom(fuente, fixedSize: tamano) : .custom(fuente, size: tamano)
        }
        return .system(size: tamano, weight: .bold, design: disenoSistema)
    }

    static var tieneLogo: Bool { UIImage(named: "Logo") != nil }
}

/// Logo (si hay) + nombre de la app con la fuente de marca. Cabecera del menú
/// lateral, como "ANDREA" en Andrea Reader.
struct Logotipo: View {
    @Environment(\.paleta) private var paleta
    var tamano: CGFloat = 40

    var body: some View {
        HStack(spacing: 12) {
            if Marca.tieneLogo {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: tamano, height: tamano)
                    .clipShape(.rect(cornerRadius: tamano * 0.22, style: .continuous))
            }
            Text(verbatim: Marca.nombre.uppercased())
                .font(Marca.titulo(tamano, fijo: true))
                .foregroundStyle(paleta.texto)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}
