import SwiftUI
import Observation

enum Pestana: String, Hashable {
    // Oficina
    case inicio, planificacion, activos, ordenes, incidencias, tecnicos, estadisticas, ajustes, mas
    // Técnico
    case misOrdenes, misIncidencias, historico
}

/// Estado de la interfaz: tema, pestaña y destinos pedidos desde avisos.
@Observable
final class AppEstado {
    var tema: Tema {
        didSet { UserDefaults.standard.set(tema.rawValue, forKey: "tema") }
    }
    var pestana: Pestana = .inicio
    var pestanaTecnico: Pestana = .misOrdenes
    /// Abrir una OT o una incidencia desde un aviso o una tarjeta de Inicio.
    var abrirOT: String?
    var abrirIncidencia: String?
    /// Filtro que Inicio pasa a Órdenes («Para hoy», «Sin asignar», «Vencidos», Histórico).
    var filtroOrdenes: FiltroRapido?
    /// Destino dentro de «Más» (iPhone).
    var masDestino: Pestana?

    init() {
        tema = Tema(rawValue: UserDefaults.standard.string(forKey: "tema") ?? "") ?? .sistema
    }
}

enum FiltroRapido: String, CaseIterable, Identifiable {
    case todos, hoy, sinAsignar, vencidos, historico
    var id: String { rawValue }
    var etiqueta: LocalizedStringKey {
        switch self {
        case .todos: "Todos"
        case .hoy: "Para hoy"
        case .sinAsignar: "Sin asignar"
        case .vencidos: "Vencidos"
        case .historico: "Histórico"
        }
    }
}
