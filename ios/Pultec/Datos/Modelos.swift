import SwiftUI

// Modelos de Pultec: espejo de las tablas de Supabase y de `app/lib/models.dart`.
// Mismos índices numéricos que la base (estado, gravedad, tipo_mantenimiento…).

/// Criticidad de un mantenimiento u OT (`tipo_mantenimiento`).
enum Criticidad: Int, CaseIterable, Identifiable {
    case preventivo, noCritico, critico
    var id: Int { rawValue }
    var etiqueta: LocalizedStringKey {
        switch self {
        case .preventivo: "Preventivo"
        case .noCritico: "Correctivo no crítico"
        case .critico: "Correctivo crítico"
        }
    }
    var corta: LocalizedStringKey {
        switch self {
        case .preventivo: "Preventivo"
        case .noCritico: "No crítico"
        case .critico: "Crítico"
        }
    }
    var color: Color {
        switch self {
        case .preventivo: .pVerde
        case .noCritico: .pAmbar
        case .critico: .pRojo
        }
    }
}

/// Estado de una OT (`trabajos.estado`). «Pausada» es En curso con `pausada_desde`.
enum EstadoOT: Int, CaseIterable {
    case pendiente, enCurso, completada, cancelada, interrumpida
    var etiqueta: LocalizedStringKey {
        switch self {
        case .pendiente: "Pendiente"
        case .enCurso: "En curso"
        case .completada: "Completada"
        case .cancelada: "Cancelada"
        case .interrumpida: "Interrumpida"
        }
    }
    var color: Color {
        switch self {
        case .pendiente: .secondary
        case .enCurso: .pAzul
        case .completada: .pVerde
        case .cancelada, .interrumpida: .pRojo
        }
    }
    var abierta: Bool { self == .pendiente || self == .enCurso }
}

enum Gravedad: Int, CaseIterable, Identifiable {
    case leve, media, grave
    var id: Int { rawValue }
    var etiqueta: LocalizedStringKey { self == .grave ? "Correctivo crítico" : "Correctivo no crítico" }
    var color: Color { self == .grave ? .pRojo : .pAmbar }
    /// Criticidad de la OT que la arregla.
    var criticidad: Criticidad { self == .grave ? .critico : .noCritico }
}

enum EstadoIncidencia: Int, CaseIterable {
    case abierta, conOt, completada, desestimada
    var etiqueta: LocalizedStringKey {
        switch self {
        case .abierta: "Abierta"
        case .conOt: "Con OT"
        case .completada: "Completada"
        case .desestimada: "Desestimada"
        }
    }
    var icono: String {
        switch self {
        case .abierta: "exclamationmark.circle"
        case .conOt: "doc.text"
        case .completada: "checkmark.circle"
        case .desestimada: "xmark.circle"
        }
    }
    var color: Color {
        switch self {
        case .abierta, .desestimada: .pRojo
        case .conOt: .pAzul
        case .completada: .pVerde
        }
    }
    var pendiente: Bool { self == .abierta || self == .conOt }
}

enum EstadoHoy: Int, CaseIterable {
    case disponible, ocupado, ausente
    var etiqueta: LocalizedStringKey {
        switch self {
        case .disponible: "Disponible"
        case .ocupado: "Ocupado"
        case .ausente: "Ausente"
        }
    }
    var color: Color {
        switch self {
        case .disponible: .pVerde
        case .ocupado: .pAmbar
        case .ausente: .pRojo
        }
    }
}

/// Resultado del parte (`informes.resultado`).
enum Resultado: Int, CaseIterable, Identifiable {
    case correcto, conIncidencias, noSePudo
    var id: Int { rawValue }
    var etiqueta: LocalizedStringKey {
        switch self {
        case .correcto: "Todo correcto"
        case .conIncidencias: "Con incidencias"
        case .noSePudo: "No se pudo hacer"
        }
    }
    var color: Color {
        switch self {
        case .correcto: .pVerde
        case .conIncidencias: .pAmbar
        case .noSePudo: .pRojo
        }
    }
}

struct PasoChecklist: Identifiable, Hashable {
    var id = UUID()
    var paso: String
    var hecho = false
    var cuando: Date?
    var por: String?

    init(paso: String, hecho: Bool = false, cuando: Date? = nil, por: String? = nil) {
        self.paso = paso; self.hecho = hecho; self.cuando = cuando; self.por = por
    }

    init(_ j: [String: Any]) {
        paso = j["paso"] as? String ?? ""
        hecho = j["hecho"] as? Bool ?? false
        cuando = Fechas.instante(j["cuando"])
        por = j["por"] as? String
    }

    var json: [String: Any] {
        var j: [String: Any] = ["paso": paso, "hecho": hecho]
        if let cuando { j["cuando"] = Fechas.iso(cuando) }
        if let por { j["por"] = por }
        return j
    }
}

struct Activo: Identifiable, Hashable {
    var id: String
    var padreId: String?
    var tag: String
    var nombre: String
    var icono: String
    var descripcion: String
    var fabricante: String
    var modelo: String
    var numeroSerie: String
    var division: String
    var repuestos: String
    var notas: String
    var horas: Double
    var usoHoras: Double
    var lecturaFecha: Date?
    var checklist: [String]

    /// Horas de hoy: la lectura más el ritmo de uso desde entonces (como `horas_hoy` de la base).
    var horasHoy: Double {
        guard let f = lecturaFecha else { return horas }
        return horas + usoHoras * Double(max(0, Fechas.dias(desde: f, hasta: Fechas.hoy)))
    }

    /// «Bomba 1 - IMP-001», como en toda la web.
    var nombreCompleto: String { tag.isEmpty ? nombre : "\(nombre) - \(tag)" }

    init(_ x: [String: Any]) {
        id = x["id"] as? String ?? UUID().uuidString.lowercased()
        padreId = x["padre_id"] as? String
        tag = x["tag"] as? String ?? ""
        nombre = x["nombre"] as? String ?? ""
        icono = x["icono"] as? String ?? "brazo"
        descripcion = x["descripcion"] as? String ?? ""
        fabricante = x["fabricante"] as? String ?? ""
        modelo = x["modelo"] as? String ?? ""
        numeroSerie = x["numero_serie"] as? String ?? ""
        division = x["division"] as? String ?? ""
        repuestos = x["repuestos"] as? String ?? ""
        notas = x["notas"] as? String ?? ""
        horas = Fechas.numero(x["horas"]) ?? 0
        usoHoras = Fechas.numero(x["uso_horas"]) ?? 0
        lecturaFecha = Fechas.dia(x["lectura_fecha"])
        checklist = x["checklist"] as? [String] ?? []
    }

    static func nuevo(padre: String? = nil) -> Activo {
        var a = Activo([:])
        a.padreId = padre
        a.lecturaFecha = Fechas.hoy
        return a
    }

    var fila: [String: Any] {
        [
            "id": id, "padre_id": padreId as Any? ?? NSNull(), "tag": tag, "nombre": nombre, "icono": icono,
            "descripcion": descripcion, "fabricante": fabricante, "modelo": modelo, "numero_serie": numeroSerie,
            "division": division, "repuestos": repuestos, "notas": notas, "horas": horas, "uso_horas": usoHoras,
            "lectura_fecha": lecturaFecha.map(Fechas.texto) as Any? ?? NSNull(), "checklist": checklist,
        ]
    }
}

struct PlanMantenimiento: Identifiable, Hashable {
    var id: String
    var activoId: String
    var nombre: String
    var descripcion: String
    var cadaDias: Int?
    var cadaHoras: Int?
    var ultimo: Date?
    var proximo: Date?
    var trabajadorId: String?
    var grupoId: String?
    var duracionMin: Int?
    var activa: Bool
    var checklist: [String]
    var procedimiento: String
    var repuestos: String
    var preparar: String
    var medicionNombre: String
    var medicionUnidad: String
    var medicionMin: Double?
    var medicionMax: Double?

    init(_ x: [String: Any]) {
        id = x["id"] as? String ?? UUID().uuidString.lowercased()
        activoId = x["activo_id"] as? String ?? ""
        nombre = x["nombre"] as? String ?? ""
        descripcion = x["descripcion"] as? String ?? ""
        cadaDias = (x["cada_dias"] as? NSNumber)?.intValue
        cadaHoras = (x["cada_horas"] as? NSNumber)?.intValue
        ultimo = Fechas.dia(x["ultimo"])
        proximo = Fechas.dia(x["proximo"])
        trabajadorId = x["trabajador_id"] as? String
        grupoId = x["grupo_id"] as? String
        duracionMin = (x["duracion_min"] as? NSNumber)?.intValue
        activa = x["activa"] as? Bool ?? true
        checklist = x["checklist"] as? [String] ?? []
        procedimiento = x["procedimiento"] as? String ?? ""
        repuestos = x["repuestos"] as? String ?? ""
        preparar = x["preparar"] as? String ?? ""
        medicionNombre = x["medicion_nombre"] as? String ?? ""
        medicionUnidad = x["medicion_unidad"] as? String ?? ""
        medicionMin = Fechas.numero(x["medicion_min"])
        medicionMax = Fechas.numero(x["medicion_max"])
    }

    static func nuevo(activo: String) -> PlanMantenimiento {
        var p = PlanMantenimiento([:])
        p.activoId = activo
        p.cadaDias = 30
        p.duracionMin = 60
        return p
    }

    var cadaCuanto: String {
        if let h = cadaHoras { return String(localized: "cada \(h) h") }
        if let d = cadaDias { return String(localized: "cada \(d) días") }
        return "—"
    }

    var fila: [String: Any] {
        [
            "id": id, "activo_id": activoId, "nombre": nombre, "descripcion": descripcion,
            "cada_dias": cadaDias as Any? ?? NSNull(), "cada_horas": cadaHoras as Any? ?? NSNull(),
            "ultimo": ultimo.map(Fechas.texto) as Any? ?? NSNull(),
            "proximo": proximo.map(Fechas.texto) as Any? ?? NSNull(),
            "trabajador_id": trabajadorId as Any? ?? NSNull(), "grupo_id": grupoId as Any? ?? NSNull(),
            "duracion_min": duracionMin as Any? ?? NSNull(), "activa": activa, "checklist": checklist,
            "procedimiento": procedimiento, "repuestos": repuestos, "preparar": preparar,
            "medicion_nombre": medicionNombre, "medicion_unidad": medicionUnidad,
            "medicion_min": medicionMin as Any? ?? NSNull(), "medicion_max": medicionMax as Any? ?? NSNull(),
        ]
    }
}

/// Orden de trabajo (`trabajos`).
struct OrdenTrabajo: Identifiable, Hashable {
    var id: String
    var nombre: String
    var descripcion: String
    var activoId: String?
    var planId: String?
    var grupoId: String?
    var proximo: Date?
    var ultimo: Date?
    var inicioMin: Int?
    var duracionMin: Int?
    var estado: EstadoOT
    var criticidad: Criticidad
    var activa: Bool
    var procedimiento: String
    var repuestos: String
    var notas: String
    var checklist: [PasoChecklist]
    var resultado: Resultado?
    var completadaEl: Date?
    var completadaPor: String?
    var iniciadaEn: Date?
    var pausadaDesde: Date?
    var segundosPausa: Int
    var tecnicoIds: [String] = []
    var creada: Date?

    init(_ x: [String: Any]) {
        id = x["id"] as? String ?? UUID().uuidString.lowercased()
        nombre = x["nombre"] as? String ?? ""
        descripcion = x["descripcion"] as? String ?? ""
        activoId = x["activo_id"] as? String
        planId = x["plan_id"] as? String
        grupoId = x["grupo_id"] as? String
        proximo = Fechas.dia(x["proximo"])
        ultimo = Fechas.dia(x["ultimo"])
        inicioMin = (x["inicio_min"] as? NSNumber)?.intValue
        duracionMin = (x["duracion_min"] as? NSNumber)?.intValue
        estado = EstadoOT(rawValue: (x["estado"] as? NSNumber)?.intValue ?? 0) ?? .pendiente
        criticidad = Criticidad(rawValue: (x["tipo_mantenimiento"] as? NSNumber)?.intValue ?? 0) ?? .preventivo
        activa = x["activa"] as? Bool ?? true
        procedimiento = x["procedimiento"] as? String ?? ""
        repuestos = x["repuestos"] as? String ?? ""
        notas = x["notas"] as? String ?? ""
        checklist = ((x["checklist"] as? [[String: Any]]) ?? []).map(PasoChecklist.init)
        resultado = (x["resultado"] as? NSNumber).flatMap { Resultado(rawValue: $0.intValue) }
        completadaEl = Fechas.instante(x["completada_el"])
        completadaPor = x["completada_por"] as? String
        iniciadaEn = Fechas.instante(x["iniciada_en"])
        pausadaDesde = Fechas.instante(x["pausada_desde"])
        segundosPausa = (x["segundos_pausa"] as? NSNumber)?.intValue ?? 0
        creada = Fechas.instante(x["created_at"])
    }

    static func nueva(activo: String? = nil) -> OrdenTrabajo {
        var t = OrdenTrabajo([:])
        t.activoId = activo
        t.proximo = Fechas.hoy
        t.duracionMin = 60
        return t
    }

    var pausada: Bool { estado == .enCurso && pausadaDesde != nil }
    var vencida: Bool { estado.abierta && (proximo.map { $0 < Fechas.hoy } ?? false) }
    var paraHoy: Bool { estado.abierta && (proximo.map { Calendar.current.isDateInToday($0) } ?? false) }

    /// «08:00–09:30».
    var franja: String? {
        guard let i = inicioMin else { return nil }
        let fin = i + (duracionMin ?? 60)
        return "\(Fechas.hora(i))–\(Fechas.hora(fin))"
    }

    /// Lo que se escribe al guardar desde la oficina (sin el estado de ejecución, que lleva la base).
    var fila: [String: Any] {
        [
            "id": id, "nombre": nombre, "descripcion": descripcion,
            "activo_id": activoId as Any? ?? NSNull(), "plan_id": planId as Any? ?? NSNull(),
            "proximo": proximo.map(Fechas.texto) as Any? ?? NSNull(),
            "inicio_min": inicioMin as Any? ?? NSNull(), "duracion_min": duracionMin as Any? ?? NSNull(),
            "tipo_mantenimiento": criticidad.rawValue, "activa": activa, "procedimiento": procedimiento,
            "repuestos": repuestos, "notas": notas, "estado": estado.rawValue,
        ]
    }
}

struct Incidencia: Identifiable, Hashable {
    var id: String
    var activoId: String
    var trabajoId: String?
    var tecnicoId: String?
    var origenTrabajoId: String?
    var planId: String?
    var descripcion: String
    var gravedad: Gravedad
    var estado: EstadoIncidencia
    var fotos: [String]
    var creada: Date
    var cerradaEl: Date?

    init(_ x: [String: Any]) {
        id = x["id"] as? String ?? UUID().uuidString.lowercased()
        activoId = x["activo_id"] as? String ?? ""
        trabajoId = x["trabajo_id"] as? String
        tecnicoId = x["tecnico_id"] as? String
        origenTrabajoId = x["origen_trabajo_id"] as? String
        planId = x["plan_id"] as? String
        descripcion = x["descripcion"] as? String ?? ""
        gravedad = Gravedad(rawValue: (x["gravedad"] as? NSNumber)?.intValue ?? 1) ?? .media
        estado = EstadoIncidencia(rawValue: (x["estado"] as? NSNumber)?.intValue ?? 0) ?? .abierta
        fotos = x["fotos"] as? [String] ?? []
        creada = Fechas.instante(x["created_at"]) ?? Date()
        cerradaEl = Fechas.instante(x["cerrada_el"])
    }

    static func nueva(activo: String = "", tecnico: String? = nil, origen: String? = nil) -> Incidencia {
        var i = Incidencia([:])
        i.activoId = activo
        i.tecnicoId = tecnico
        i.origenTrabajoId = origen
        return i
    }
}

struct Tecnico: Identifiable, Hashable {
    var id: String
    var nombre: String
    var apellidos: String
    var telefono: String
    var email: String
    var info: String
    var color: Int
    var estadoHoy: EstadoHoy
    var grupoIds: [String]
    var activosElegidos: [String]
    var activo: Bool

    init(_ x: [String: Any]) {
        id = x["id"] as? String ?? UUID().uuidString.lowercased()
        nombre = x["nombre"] as? String ?? ""
        apellidos = x["apellidos"] as? String ?? ""
        telefono = x["telefono"] as? String ?? ""
        email = x["email"] as? String ?? ""
        info = x["info"] as? String ?? ""
        color = (x["color"] as? NSNumber)?.intValue ?? 0
        estadoHoy = EstadoHoy(rawValue: (x["estado_hoy"] as? NSNumber)?.intValue ?? 0) ?? .disponible
        grupoIds = x["grupo_ids"] as? [String] ?? []
        activosElegidos = x["activos_elegidos"] as? [String] ?? []
        activo = x["activo"] as? Bool ?? true
    }

    static func nuevo() -> Tecnico {
        var t = Tecnico([:])
        t.color = Int.random(in: 0..<Tecnico.colores.count)
        return t
    }

    /// Paleta de la web (`paleta` en theme.dart): `trabajadores.color` es el índice.
    static let colores: [UInt32] = [0x5B3BE6, 0x0F9F8F, 0x2563EB, 0x16A34A, 0xEA580C, 0xDB2777, 0x0891B2, 0xCA8A04]

    var nombreCompleto: String { [nombre, apellidos].filter { !$0.isEmpty }.joined(separator: " ") }
    var iniciales: String {
        let partes = [nombre, apellidos].compactMap { $0.first.map(String.init) }
        return partes.joined().uppercased()
    }
    var colorSwift: Color { Color(hex: Tecnico.colores[((color % Tecnico.colores.count) + Tecnico.colores.count) % Tecnico.colores.count]) }

    var fila: [String: Any] {
        [
            "id": id, "nombre": nombre, "apellidos": apellidos, "telefono": telefono, "email": email,
            "info": info, "color": color, "estado_hoy": estadoHoy.rawValue, "grupo_ids": grupoIds, "activo": activo,
        ]
    }
}

struct Grupo: Identifiable, Hashable {
    var id: String
    var nombre: String
    init(_ x: [String: Any]) {
        id = x["id"] as? String ?? UUID().uuidString.lowercased()
        nombre = x["nombre"] as? String ?? ""
    }
}

struct Informe: Identifiable, Hashable {
    var id: String
    var trabajoId: String
    var trabajadorId: String?
    var resultado: Resultado
    var notas: String
    var material: String
    var minutos: Int?
    var valor: Double?
    var fotos: [String]
    var firma: String?
    var cuando: Date

    init(_ x: [String: Any]) {
        id = x["id"] as? String ?? ""
        trabajoId = x["trabajo_id"] as? String ?? ""
        trabajadorId = x["trabajador_id"] as? String
        resultado = Resultado(rawValue: (x["resultado"] as? NSNumber)?.intValue ?? 0) ?? .correcto
        notas = x["notas"] as? String ?? ""
        material = x["material"] as? String ?? ""
        minutos = (x["minutos"] as? NSNumber)?.intValue
        valor = Fechas.numero(x["valor"])
        fotos = x["fotos"] as? [String] ?? []
        firma = x["firma"] as? String
        cuando = Fechas.instante(x["created_at"]) ?? Date()
    }
}

/// Aviso en vivo de la campana (calculado a partir de los datos).
struct Aviso: Identifiable, Hashable {
    enum Destino: Hashable { case ot(String), incidencia(String), ordenesSinTecnico }
    let id: String
    let titulo: String
    let detalle: String
    let cuando: Date
    let color: Color
    let destino: Destino
}

extension Color {
    static let pMorado = Color(hex: 0x5B3BE6)
    static let pVerde = Color(hex: 0x16A34A)
    static let pRojo = Color(hex: 0xE5484D)
    static let pAmbar = Color(hex: 0xD97706)
    static let pAzul = Color(hex: 0x2563EB)
    static let pAmarillo = Color(hex: 0xF5B800)
    static let pGris = Color(hex: 0x71717A)

    init(argb: Int) {
        self.init(hex: UInt32(truncatingIfNeeded: argb & 0xFFFFFF))
    }
}
