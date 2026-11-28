import SwiftUI

// Piezas reutilizables de Pultec iOS (estilo Andrea Reader). Antes de crear una
// vista nueva, reutiliza estas; si hace falta otra, créala aquí con nombre.
// Reglas: hojas de formulario con X a la izquierda, ✓ a la derecha y título
// centrado; hojas de consulta con X a la derecha; nunca texto en esos botones.
// El color (puntos, insignias, anillos) sustituye al icono: cuantos menos, mejor.

// MARK: Fondo y títulos

struct FondoTema: ViewModifier {
    @Environment(\.paleta) private var paleta

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(paleta.degradado.ignoresSafeArea())
    }
}

extension View {
    func fondoTema() -> some View { modifier(FondoTema()) }

    /// Título de pantalla raíz a la izquierda (icono 14 + texto 15 semibold), como Andrea.
    func tituloPantalla(_ titulo: LocalizedStringKey, icono: String) -> some View {
        modifier(TituloPantalla(titulo: Text(titulo), icono: icono))
    }

    /// Hoja con el tema de la app (paleta, colores de texto y acento).
    func conTema(_ paleta: Paleta) -> some View {
        environment(\.paleta, paleta)
            .tint(paleta.acento)
    }
}

struct TituloPantalla: ViewModifier {
    @Environment(\.paleta) private var paleta
    let titulo: Text
    let icono: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Simbolo(nombre: icono).font(.system(size: 14, weight: .semibold))
                        titulo.font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(paleta.texto)
                    .fixedSize()
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar(removing: .title)
    }
}

// MARK: Superficies

struct Tarjeta<Contenido: View>: View {
    @Environment(\.paleta) private var paleta
    var relleno: CGFloat = 16
    @ViewBuilder let contenido: Contenido

    var body: some View {
        contenido
            .padding(relleno)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(paleta.superficie, in: .rect(cornerRadius: 16, style: .continuous))
    }
}

/// Encabezado de bloque: título y, opcional, cifra en color.
struct EncabezadoBloque: View {
    let titulo: LocalizedStringKey
    var cifra: Int? = nil
    var color: Color = .secondary

    var body: some View {
        HStack(spacing: 6) {
            Text(titulo).font(.app(.headline, .semibold))
            if let cifra { Text("\(cifra)").font(.app(.headline, .semibold)).foregroundStyle(color) }
            Spacer(minLength: 0)
        }
    }
}

/// Cifra grande del resumen: icono en cuadrado tintado, título, número y subtítulo, barrita de color abajo.
struct TarjetaCifra: View {
    @Environment(\.paleta) private var paleta
    let titulo: LocalizedStringKey
    let valor: Int
    let subtitulo: LocalizedStringKey
    let icono: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icono)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.13), in: .rect(cornerRadius: 9, style: .continuous))
                Text(titulo).font(.app(.subheadline, .medium)).foregroundStyle(.secondary).lineLimit(1)
            }
            Text("\(valor)").font(.system(size: 30, weight: .semibold)).foregroundStyle(valor > 0 && color == .pRojo ? color : paleta.texto)
                .contentTransition(.numericText())
            Text(subtitulo).font(.app(.caption)).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(paleta.superficie, in: .rect(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .bottom) {
            Capsule().fill(color).frame(height: 3).padding(.horizontal, 14)
        }
    }
}

// MARK: Color en vez de iconos

struct Punto: View {
    let color: Color
    var tamano: CGFloat = 8
    var body: some View { Circle().fill(color).frame(width: tamano, height: tamano) }
}

/// Píldora con punto (criticidad, estado…).
struct Insignia: View {
    let texto: LocalizedStringKey
    let color: Color
    var punto = true
    var icono: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let icono { Image(systemName: icono).font(.system(size: 10, weight: .bold)) }
            else if punto { Punto(color: color, tamano: 6) }
            Text(texto).font(.app(.caption, .medium)).lineLimit(1)
        }
        .foregroundStyle(color == .secondary ? Color.secondary : color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background((color == .secondary ? Color.gray : color).opacity(0.12), in: .capsule)
    }
}

/// Anillo de ciclo del mantenimiento: lleno = recién hecho; ámbar < 20 %; rojo < 10 %.
struct AnilloCiclo: View {
    let valor: Double
    var tamano: CGFloat = 18

    private var color: Color { valor < 0.1 ? .pRojo : valor < 0.2 ? .pAmbar : .pVerde }

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: 3)
            Circle().trim(from: 0, to: max(0.02, valor))
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: tamano, height: tamano)
        .accessibilityHidden(true)
    }
}

/// Círculo de estado de la OT: vacío pendiente, azul en curso, verde hecha.
struct CirculoEstado: View {
    let ot: OrdenTrabajo

    var body: some View {
        switch ot.estado {
        case .completada:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.pVerde)
        case .cancelada, .interrumpida:
            Image(systemName: "xmark.circle").foregroundStyle(Color.pRojo)
        case .enCurso:
            Image(systemName: ot.pausada ? "pause.circle.fill" : "circle.dotted.circle").foregroundStyle(Color.pAzul)
        case .pendiente:
            Image(systemName: "circle").foregroundStyle(ot.vencida ? Color.pRojo : Color.secondary)
        }
    }
}

struct Avatar: View {
    let tecnico: Tecnico?
    var tamano: CGFloat = 28
    var conEstado = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let tecnico {
                    Text(tecnico.iniciales)
                        .font(.system(size: tamano * 0.38, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: tamano, height: tamano)
                        .background(tecnico.colorSwift, in: .circle)
                } else {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: tamano * 0.6))
                        .foregroundStyle(.secondary)
                        .frame(width: tamano, height: tamano)
                }
            }
            if conEstado, let tecnico {
                Punto(color: tecnico.estadoHoy.color, tamano: tamano * 0.3)
                    .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 2))
            }
        }
        .accessibilityLabel(Text(tecnico?.nombreCompleto ?? String(localized: "Sin técnico")))
    }
}

/// Icono del activo según su clave (mismas claves que la web: brazo, camion, bomba…). En gris: el activo no tiene criticidad.
struct IconoActivo: View {
    let clave: String
    var tamano: CGFloat = 34

    static let catalogo: [(String, LocalizedStringKey, String)] = [
        ("brazo", "Brazo industrial", "IconoActivos"),
        ("camion", "Camión", "truck.box"),
        ("fabrica", "Máquina industrial", "building.2"),
        ("motor", "Motor", "gearshape"),
        ("compresor", "Compresor", "wind"),
        ("bomba", "Bomba de agua", "drop"),
        ("electrico", "Equipo eléctrico", "bolt"),
        ("herramientas", "Herramientas", "wrench.and.screwdriver"),
        ("mantenimiento", "Equipo de mantenimiento", "hammer"),
        ("tractor", "Tractor", "tractor"),
        ("combustible", "Depósito de combustible", "fuelpump"),
        ("medidor", "Medidor", "gauge.with.dots.needle.33percent"),
    ]

    static func simbolo(_ clave: String) -> String {
        catalogo.first { $0.0 == clave }?.2 ?? "IconoActivos"
    }

    var body: some View {
        Simbolo(nombre: Self.simbolo(clave))
            .font(.system(size: tamano * 0.45, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: tamano, height: tamano)
            .background(Color.gray.opacity(0.12), in: .rect(cornerRadius: tamano * 0.28, style: .continuous))
    }
}

// MARK: Filas

/// Fila de OT para todas las listas (oficina y técnico).
struct FilaOT: View {
    @Environment(Almacen.self) private var almacen
    let ot: OrdenTrabajo
    var mostrarTecnico = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CirculoEstado(ot: ot).font(.system(size: 18)).padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(ot.nombre).font(.app(.body, .semibold)).lineLimit(1)
                if let a = almacen.activo(ot.activoId) {
                    Text(a.nombreCompleto).font(.app(.subheadline)).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 6) {
                    Insignia(texto: ot.criticidad.corta, color: ot.criticidad.color)
                    if ot.estado == .enCurso {
                        Insignia(texto: ot.pausada ? "Pausada" : "En curso", color: .pAzul)
                    } else if ot.vencida {
                        Insignia(texto: "Vencida", color: .pRojo, icono: "exclamationmark.triangle")
                    }
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                if let p = ot.proximo ?? ot.ultimo {
                    Text(Fechas.corta(p)).font(.app(.caption)).foregroundStyle(.secondary)
                }
                if let f = ot.franja { Text(f).font(.app(.caption2)).foregroundStyle(.tertiary) }
                if mostrarTecnico { Avatar(tecnico: almacen.tecnico(ot.tecnicoIds.first), tamano: 24) }
            }
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
    }
}

struct FilaIncidencia: View {
    @Environment(Almacen.self) private var almacen
    let incidencia: Incidencia

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: incidencia.estado.icono)
                .foregroundStyle(incidencia.estado == .abierta ? incidencia.gravedad.color : incidencia.estado.color)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 4) {
                Text(incidencia.descripcion).font(.app(.body, .semibold)).lineLimit(2)
                Text(almacen.activo(incidencia.activoId)?.nombreCompleto ?? "")
                    .font(.app(.subheadline)).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 6) {
                    Insignia(texto: incidencia.gravedad.etiqueta, color: incidencia.gravedad.color)
                    Insignia(texto: incidencia.estado.etiqueta, color: incidencia.estado.color, icono: incidencia.estado.icono)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Text(Fechas.relativo(incidencia.creada)).font(.app(.caption)).foregroundStyle(.secondary)
                Avatar(tecnico: almacen.tecnico(incidencia.tecnicoId), tamano: 22)
            }
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
    }
}

struct FilaActivo: View {
    @Environment(Almacen.self) private var almacen
    let activo: Activo

    var body: some View {
        let planes = almacen.planesDe(activo.id)
        let proximo = planes.compactMap { almacen.otAbierta(de: $0)?.proximo }.min()
        HStack(spacing: 12) {
            IconoActivo(clave: activo.icono)
            VStack(alignment: .leading, spacing: 3) {
                Text(activo.nombreCompleto).font(.app(.body, .semibold)).lineLimit(1)
                Group {
                    if let proximo {
                        Text("Próximo \(Fechas.corta(proximo))").foregroundStyle(proximo < Fechas.hoy ? Color.pRojo : Color.secondary)
                    } else {
                        Text("Sin mantenimientos").foregroundStyle(.secondary)
                    }
                }
                .font(.app(.subheadline))
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(activo.horasHoy)) h").font(.app(.subheadline, .medium))
                let c = almacen.hijos(activo.id).count
                if c > 0 {
                    Label("\(c)", systemImage: "square.stack.3d.up").font(.app(.caption)).foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(.rect)
    }
}

// MARK: Vacíos, carga y avisos

/// Vacío centrado con icono en círculo, como la web (nunca datos inventados).
struct EstadoVacio: View {
    let icono: String
    let titulo: LocalizedStringKey
    var mensaje: LocalizedStringKey? = nil

    var body: some View {
        VStack(spacing: 12) {
            Simbolo(nombre: icono)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 56, height: 56)
                .background(Color.gray.opacity(0.12), in: .circle)
            Text(titulo).font(.app(.headline)).multilineTextAlignment(.center)
            if let mensaje {
                Text(mensaje).font(.app(.subheadline)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

/// Aviso breve abajo («Incidencia enviada»).
struct Toast: View {
    let texto: String
    var error = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: error ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(error ? Color.pRojo : Color.pVerde)
            Text(texto).font(.app(.subheadline, .medium)).foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.85), in: .capsule)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// Consejo morado con bombilla y X (va en el `header:` de una sección, nunca como fila).
struct Consejo: View {
    let texto: LocalizedStringKey
    let clave: String
    @AppStorage private var cerrado: Bool

    init(_ texto: LocalizedStringKey, clave: String) {
        self.texto = texto
        self.clave = clave
        _cerrado = AppStorage(wrappedValue: false, "consejo.\(clave)")
    }

    var body: some View {
        if !cerrado {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb").foregroundStyle(Color.pMorado)
                Text(texto).font(.app(.footnote)).foregroundStyle(Color.pMorado).frame(maxWidth: .infinity, alignment: .leading)
                Button { withAnimation { cerrado = true } } label: { Image(systemName: "xmark").font(.caption.bold()) }
                    .buttonStyle(.plain).foregroundStyle(Color.pMorado)
                    .accessibilityLabel(Text("Cerrar consejo"))
            }
            .padding(12)
            .background(Color.pMorado.opacity(0.08), in: .rect(cornerRadius: 12, style: .continuous))
            .textCase(nil)
        }
    }
}

// MARK: Botones de hoja

/// Cerrar una hoja: X, nunca texto.
struct BotonCerrar: View {
    @Environment(\.dismiss) private var dismiss
    var accion: (() -> Void)? = nil

    var body: some View {
        Button(role: .close) { accion?() ?? dismiss() } label: { Image(systemName: "xmark") }
            .accessibilityLabel(Text("Cerrar"))
    }
}

/// Confirmar un formulario: ✓, apagado hasta que se pueda guardar.
struct BotonConfirmar: View {
    let activo: Bool
    let accion: () -> Void

    var body: some View {
        Button(role: .confirm, action: accion) { Image(systemName: "checkmark") }
            .disabled(!activo)
            .accessibilityLabel(Text("Guardar"))
    }
}

extension View {
    /// Hoja de formulario Andrea: X a la izquierda, ✓ a la derecha, título centrado.
    func hojaFormulario(_ titulo: String, puedeGuardar: Bool, guardar: @escaping () -> Void) -> some View {
        navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { BotonCerrar() }
                ToolbarItem(placement: .topBarTrailing) { BotonConfirmar(activo: puedeGuardar, accion: guardar) }
            }
    }

    /// Hoja de consulta: X arriba a la derecha.
    func hojaConsulta(_ titulo: String) -> some View {
        navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { BotonCerrar() } }
    }
}

/// Aviso rojo abajo del formulario: «Te falta …».
struct AvisoFalta: View {
    let texto: LocalizedStringKey
    var body: some View {
        Label(texto, systemImage: "exclamationmark.triangle")
            .font(.app(.footnote, .medium))
            .foregroundStyle(Color.pRojo)
            .textCase(nil)
    }
}

// MARK: Pila de navegación

extension EnvironmentValues {
    /// La vista ya está dentro de una pila (p. ej. «Más» en iPhone): no abre otra.
    @Entry var dentroDePila = false
}

/// NavigationStack salvo que ya haya una por encima.
struct Pila<Contenido: View>: View {
    @Environment(\.dentroDePila) private var dentro
    @ViewBuilder let contenido: Contenido

    var body: some View {
        if dentro { contenido } else { NavigationStack { contenido } }
    }
}

/// Símbolo del sistema o imagen propia de Assets (p. ej. «IconoActivos», el brazo de la web).
struct Simbolo: View {
    let nombre: String
    var body: some View {
        if UIImage(named: nombre) != nil { Image(nombre).renderingMode(.template) } else { Image(systemName: nombre) }
    }
}
