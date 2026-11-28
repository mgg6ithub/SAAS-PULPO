import SwiftUI

/// Campana: avisos en vivo. Tocar uno abre lo que nombra.
struct BotonAvisos: View {
    @Environment(Almacen.self) private var almacen
    @State private var abierto = false

    var body: some View {
        Button { abierto = true } label: {
            Image(systemName: almacen.sinLeer > 0 ? "bell.badge" : "bell")
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.pRojo, Color.primary)
        }
        .accessibilityLabel(Text("Avisos"))
        .sheet(isPresented: $abierto) {
            AvisosView().presentationDetents([.medium, .large])
        }
    }
}

struct AvisosView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if almacen.avisos.isEmpty {
                    Section {} header: {
                        EstadoVacio(icono: "bell", titulo: "Sin avisos", mensaje: "Aquí llegan las incidencias, las órdenes cerradas y lo que te asignen.")
                            .textCase(nil)
                    }
                } else {
                    Section {
                        ForEach(almacen.avisos) { a in
                            Button { abrir(a) } label: { fila(a) }.buttonStyle(.plain)
                        }
                    } header: {
                        if almacen.sinLeer > 0 {
                            Text(almacen.sinLeer == 1 ? "Un aviso sin leer" : "\(almacen.sinLeer) sin leer")
                        }
                    }
                }
            }
            .fondoTema()
            .hojaConsulta(String(localized: "Avisos"))
            .toolbar {
                if almacen.sinLeer > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { withAnimation { almacen.marcarLeidos() } } label: { Image(systemName: "checkmark.circle") }
                            .accessibilityLabel(Text("Marcar todo leído"))
                    }
                }
            }
        }
    }

    private func fila(_ a: Aviso) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Capsule().fill(a.color).frame(width: 3)
            VStack(alignment: .leading, spacing: 3) {
                Text(a.titulo).font(.app(.subheadline, almacen.leidos.contains(a.id) ? .regular : .semibold))
                if !a.detalle.isEmpty { Text(a.detalle).font(.app(.caption)).foregroundStyle(.secondary) }
            }
            Spacer()
            Text(Fechas.relativo(a.cuando)).font(.app(.caption2)).foregroundStyle(.secondary)
        }
        .contentShape(.rect)
    }

    private func abrir(_ a: Aviso) {
        almacen.leidos.insert(a.id)
        UserDefaults.standard.set(Array(almacen.leidos), forKey: "pultec.leidos")
        switch a.destino {
        case .ot(let id):
            estado.abrirOT = id
            if almacen.tecnicoActivo != nil { estado.pestanaTecnico = .misOrdenes } else { estado.pestana = .ordenes }
        case .incidencia(let id):
            estado.abrirIncidencia = id
            estado.pestana = .incidencias
        case .ordenesSinTecnico:
            estado.filtroOrdenes = .sinAsignar
            estado.pestana = .ordenes
        }
        dismiss()
    }
}
