import SwiftUI

/// Raíz: entrar → oficina o técnico. Barra de pestañas abajo en iPhone y barra
/// lateral en iPad (`sidebarAdaptable`), como la barra lateral de la web.
struct RaizView: View {
    @Environment(AppEstado.self) private var estado
    @Environment(Almacen.self) private var almacen
    @Environment(\.colorScheme) private var esquemaSistema

    var body: some View {
        let paleta = estado.tema.paleta(esquemaSistema)
        ZStack(alignment: .bottom) {
            switch almacen.fase {
            case .comprobando, .cargando:
                Cargando()
            case .fuera:
                EntrarView()
            case .error(let mensaje):
                ErrorEntrada(mensaje: mensaje)
            case .dentro:
                if almacen.tecnicoActivo != nil {
                    TecnicoRaiz()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    OficinaRaiz()
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            if let t = almacen.toast { Toast(texto: t).zIndex(2) }
        }
        .animation(.easeInOut(duration: 0.25), value: almacen.tecnicoActivo)
        .conTema(paleta)
    }
}

private struct Cargando: View {
    var body: some View {
        VStack(spacing: 16) {
            Image("Logo").resizable().scaledToFit().frame(width: 72, height: 72)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
                .symbolEffect(.pulse)
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoTema()
    }
}

private struct ErrorEntrada: View {
    @Environment(Almacen.self) private var almacen
    let mensaje: String

    var body: some View {
        VStack(spacing: 16) {
            EstadoVacio(icono: "wifi.exclamationmark", titulo: "No se pudo abrir Pultec", mensaje: LocalizedStringKey(mensaje))
            Button("Reintentar") { Task { await almacen.arrancar() } }.buttonStyle(.glassProminent)
            Button("Cerrar sesión", role: .destructive) { Task { await almacen.salir() } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoTema()
    }
}

/// Oficina: Inicio · Planificación · Activos · Órdenes · Incidencias · Técnicos · Estadísticas.
/// En iPhone la barra enseña las cinco primeras y el resto va en «Más» (lo gestiona el sistema).
struct OficinaRaiz: View {
    @Environment(AppEstado.self) private var estado
    @Environment(Almacen.self) private var almacen

    var body: some View {
        @Bindable var estado = estado
        TabView(selection: $estado.pestana) {
            Tab("Inicio", systemImage: "house", value: Pestana.inicio) { InicioView() }
            Tab("Planificación", systemImage: "calendar", value: Pestana.planificacion) { PlanificacionView() }
                .badge(almacen.pendientes.filter(\.vencida).count)
            Tab("Activos", systemImage: "gearshape.2", value: Pestana.activos) { ActivosView() }
            Tab("Órdenes", systemImage: "list.clipboard", value: Pestana.ordenes) { OrdenesView() }
            Tab("Incidencias", systemImage: "exclamationmark.circle", value: Pestana.incidencias) { IncidenciasView() }
                .badge(almacen.incidenciasAbiertas.count)
            Tab("Técnicos", systemImage: "person.2", value: Pestana.tecnicos) { TecnicosView() }
            Tab("Estadísticas", systemImage: "chart.xyaxis.line", value: Pestana.estadisticas) { EstadisticasView() }
            Tab("Ajustes", systemImage: "gearshape", value: Pestana.ajustes) { AjustesView() }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

/// Técnico: Órdenes · Incidencias · Histórico. «Crear incidencia» siempre a mano.
struct TecnicoRaiz: View {
    @Environment(AppEstado.self) private var estado
    @Environment(Almacen.self) private var almacen

    var body: some View {
        @Bindable var estado = estado
        let yo = almacen.tecnicoActivo ?? ""
        TabView(selection: $estado.pestanaTecnico) {
            Tab("Órdenes", systemImage: "list.clipboard", value: Pestana.misOrdenes) { MisOrdenesView() }
                .badge(almacen.misOrdenes(yo).count)
            Tab("Incidencias", systemImage: "exclamationmark.circle", value: Pestana.misIncidencias) { MisIncidenciasView() }
            Tab("Histórico", systemImage: "clock.arrow.circlepath", value: Pestana.historico) { HistoricoTecnicoView() }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
