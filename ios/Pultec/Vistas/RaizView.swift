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

/// Oficina: Inicio · Planificación · Activos · Órdenes · Incidencias · Técnicos · Estadísticas.
/// En iPhone la barra enseña las cinco primeras y el resto va en «Más» (lo gestiona el sistema).
struct OficinaRaiz: View {
    @Environment(AppEstado.self) private var estado
    @Environment(Almacen.self) private var almacen
    @Environment(\.horizontalSizeClass) private var ancho

    var body: some View {
        @Bindable var estado = estado
        TabView(selection: $estado.pestana) {
            Tab("Inicio", systemImage: "house", value: Pestana.inicio) { InicioView() }
            Tab("Planificación", systemImage: "calendar", value: Pestana.planificacion) { PlanificacionView() }
                .badge(almacen.pendientes.filter(\.vencida).count)
            Tab("Activos", systemImage: "gearshape.2", value: Pestana.activos) { ActivosView() }
            Tab("Órdenes", systemImage: "list.clipboard", value: Pestana.ordenes) { OrdenesView() }
            if ancho == .compact {
                // iPhone: el resto en «Más», con su propia pila (la del sistema duplica la barra).
                Tab("Más", systemImage: "ellipsis", value: Pestana.mas) { MasView() }
                    .badge(almacen.incidenciasAbiertas.count)
            } else {
                Tab("Incidencias", systemImage: "exclamationmark.circle", value: Pestana.incidencias) { IncidenciasView() }
                    .badge(almacen.incidenciasAbiertas.count)
                Tab("Técnicos", systemImage: "person.2", value: Pestana.tecnicos) { TecnicosView() }
                Tab("Estadísticas", systemImage: "chart.xyaxis.line", value: Pestana.estadisticas) { EstadisticasView() }
                Tab("Ajustes", systemImage: "gearshape", value: Pestana.ajustes) { AjustesView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: estado.pestana) { _, p in
            // Un aviso pide Incidencias en iPhone: se abre dentro de «Más».
            if ancho == .compact, p == .incidencias { estado.pestana = .mas; estado.masDestino = .incidencias }
        }
    }
}

/// «Más» en iPhone: Incidencias, Técnicos, Estadísticas y Ajustes.
struct MasView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(AppEstado.self) private var estado
    @State private var ruta: [Pestana] = []

    var body: some View {
        NavigationStack(path: $ruta) {
            List {
                fila(.incidencias, "Incidencias", "exclamationmark.circle", almacen.incidenciasAbiertas.count, .pRojo)
                fila(.tecnicos, "Técnicos", "person.2", 0, .pMorado)
                fila(.estadisticas, "Estadísticas", "chart.xyaxis.line", 0, .pMorado)
                fila(.ajustes, "Ajustes", "gearshape", 0, .pMorado)
            }
            .fondoTema()
            .tituloPantalla("Más", icono: "ellipsis")
            .navigationDestination(for: Pestana.self) { p in
                Group {
                    switch p {
                    case .incidencias: IncidenciasView()
                    case .tecnicos: TecnicosView()
                    case .estadisticas: EstadisticasView()
                    default: AjustesView()
                    }
                }
                .environment(\.dentroDePila, true)
            }
            .onAppear(perform: ir)
            .onChange(of: estado.masDestino) { ir() }
        }
    }

    private func ir() {
        if let d = estado.masDestino { estado.masDestino = nil; ruta = [d] }
    }

    private func fila(_ p: Pestana, _ t: LocalizedStringKey, _ i: String, _ n: Int, _ c: Color) -> some View {
        NavigationLink(value: p) {
            Label { Text(t) } icon: { Image(systemName: i).foregroundStyle(c) }
                .badge(n)
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
