import SwiftUI

/// Raíz: entrar → oficina o técnico. Barra de pestañas abajo en iPhone y barra
/// lateral en iPad (`sidebarAdaptable`), como la barra lateral de la web.
struct RaizView: View {
    @Environment(AppEstado.self) private var estado
    @Environment(Almacen.self) private var almacen
    @Environment(\.colorScheme) private var esquemaSistema

    var body: some View {
        let paleta = estado.tema.paleta(esquemaSistema)
        ZStack(alignment: .top) {
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
            if let t = almacen.toast { Toast(texto: t, error: almacen.toastError).zIndex(2) }
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

/// Oficina. Barra principal: Inicio · Planificación · Estadísticas · Ajustes · Más (›).
/// «Más» transforma la barra en la de activos: ‹ · Activos · Órdenes · Incidencias (en rojo) · Técnicos;
/// la flecha vuelve a la principal (a la pestaña en la que estaba).
struct OficinaRaiz: View {
    @Environment(AppEstado.self) private var estado
    @Environment(Almacen.self) private var almacen

    /// Icono de Incidencias en rojo también en la barra (el sistema pinta los demás con el acento).
    private static let iconoIncidencias: UIImage = {
        let conf = UIImage.SymbolConfiguration(weight: .regular)
        return (UIImage(systemName: "exclamationmark.circle.fill", withConfiguration: conf) ?? UIImage())
            .withTintColor(UIColor(red: 0.898, green: 0.282, blue: 0.302, alpha: 1), renderingMode: .alwaysOriginal)
    }()

    var body: some View {
        @Bindable var estado = estado
        TabView(selection: $estado.pestana) {
            if estado.barraActivos {
                Tab("Atrás", systemImage: "chevron.backward", value: Pestana.volver) { Color.clear }
                Tab(value: Pestana.activos) { ActivosView() } label: { Label("Activos", image: "IconoActivos") }
                Tab("Órdenes", systemImage: "list.clipboard", value: Pestana.ordenes) { OrdenesView() }
                Tab(value: Pestana.incidencias) { IncidenciasView() } label: {
                    Label { Text("Incidencias") } icon: { Image(uiImage: Self.iconoIncidencias) }
                }
                .badge(almacen.incidenciasAbiertas.count)
                Tab("Técnicos", systemImage: "person.2", value: Pestana.tecnicos) { TecnicosView() }
            } else {
                Tab("Inicio", systemImage: "house", value: Pestana.inicio) { InicioView() }
                Tab("Planificación", systemImage: "calendar", value: Pestana.planificacion) { PlanificacionView() }
                    .badge(almacen.pendientes.filter(\.vencida).count)
                Tab("Estadísticas", systemImage: "chart.xyaxis.line", value: Pestana.estadisticas) { EstadisticasView() }
                Tab("Ajustes", systemImage: "gearshape", value: Pestana.ajustes) { AjustesView() }
                Tab("Más", systemImage: "chevron.forward", value: Pestana.entrarActivos) { Color.clear }
                    .badge(almacen.incidenciasAbiertas.count)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .sensoryFeedback(.selection, trigger: estado.barraActivos)
        .onChange(of: estado.pestana) { antes, ahora in
            switch ahora {
            case .entrarActivos:
                if !Pestana.deActivos.contains(antes) { estado.antesDeActivos = antes }
                withAnimation(.smooth(duration: 0.35)) { estado.barraActivos = true; estado.pestana = .activos }
            case .volver:
                withAnimation(.smooth(duration: 0.35)) { estado.barraActivos = false; estado.pestana = estado.antesDeActivos }
            default:
                // Un aviso o una tarjeta pide una pestaña de la otra barra: se cambia de barra.
                let deActivos = Pestana.deActivos.contains(ahora)
                if deActivos != estado.barraActivos {
                    if deActivos { estado.antesDeActivos = antes }
                    withAnimation(.smooth(duration: 0.35)) { estado.barraActivos = deActivos }
                }
            }
        }
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
