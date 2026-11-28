import SwiftUI

/// Órdenes de trabajo: Pendientes / Histórico / Canceladas, criticidad, filtros rápidos,
/// búsqueda; tocar → ficha de la OT.
struct OrdenesView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(AppEstado.self) private var estado
    @State private var vista: VistaOrdenes = .pendientes
    @State private var rapido: FiltroRapido = .todos
    @State private var criticidad: Criticidad?
    @State private var tecnicoFiltro: String?
    @State private var buscar = ""
    @State private var nueva = false
    @State private var ruta = NavigationPath()

    enum VistaOrdenes: String, CaseIterable { case pendientes, historico, canceladas }

    private var lista: [OrdenTrabajo] {
        var r: [OrdenTrabajo]
        switch vista {
        case .pendientes: r = almacen.pendientes
        case .historico: r = almacen.historico
        case .canceladas: r = almacen.canceladas
        }
        if vista == .pendientes {
            switch rapido {
            case .hoy: r = r.filter(\.paraHoy)
            case .sinAsignar: r = r.filter { $0.tecnicoIds.isEmpty }
            case .vencidos: r = r.filter(\.vencida)
            default: break
            }
        }
        if let criticidad { r = r.filter { $0.criticidad == criticidad } }
        if let tecnicoFiltro { r = r.filter { $0.tecnicoIds.contains(tecnicoFiltro) } }
        if !buscar.isEmpty {
            r = r.filter {
                $0.nombre.localizedCaseInsensitiveContains(buscar)
                    || (almacen.activo($0.activoId)?.nombreCompleto.localizedCaseInsensitiveContains(buscar) ?? false)
            }
        }
        return r
    }

    var body: some View {
        NavigationStack(path: $ruta) {
            List {
                Section {} header: { cabecera }
                if vista == .pendientes {
                    Section {} header: {
                        Consejo("Las órdenes que se repiten se crean solas: crea un mantenimiento en su activo y Pultec generará cada orden cuando toque. Aquí, solo las sueltas.", clave: "ordenes-solas")
                    }
                }
                Section {
                    ForEach(lista) { o in
                        NavigationLink(value: o.id) { FilaOT(ot: o) }
                            .swipeActions(edge: .trailing) {
                                if o.estado.abierta {
                                    Button(role: .destructive) { Task { await almacen.cambiarEstado(o, .cancelada) } } label: {
                                        Label("Cancelar", systemImage: "xmark.circle")
                                    }
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if o.estado.abierta { MenuAsignar(ot: o) }
                            }
                    }
                } footer: {
                    Text(lista.count == 1 ? "Una orden de trabajo" : "\(lista.count) órdenes de trabajo")
                        .frame(maxWidth: .infinity)
                }
                if lista.isEmpty {
                    Section {} header: {
                        EstadoVacio(icono: "list.clipboard", titulo: vista == .canceladas ? "No hay ninguna orden cancelada" : "No hay órdenes con estos filtros")
                            .textCase(nil)
                    }
                }
            }
            .searchable(text: $buscar, prompt: "Buscar orden de trabajo…")
            .refreshable { await almacen.recargar() }
            .fondoTema()
            .tituloPantalla("Órdenes de trabajo", icono: "list.clipboard")
            .navigationDestination(for: String.self) { OTDetalleView(otId: $0) }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Criticidad", selection: $criticidad) {
                            Text("Todas").tag(Criticidad?.none)
                            ForEach(Criticidad.allCases) { c in
                                Label { Text(c.etiqueta) } icon: { Image(systemName: "circle.fill") }.tint(c.color).tag(Criticidad?.some(c))
                            }
                        }
                        Picker("Técnico", selection: $tecnicoFiltro) {
                            Text("Todos los técnicos").tag(String?.none)
                            ForEach(almacen.tecnicos) { Text($0.nombreCompleto).tag(String?.some($0.id)) }
                        }
                        .pickerStyle(.menu)
                    } label: {
                        Image(systemName: criticidad == nil && tecnicoFiltro == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                    }
                    .accessibilityLabel(Text("Filtros"))
                    Button { nueva = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel(Text("Orden de trabajo"))
                        .keyboardShortcut("n", modifiers: [])
                    BotonAvisos()
                }
            }
            .sheet(isPresented: $nueva) { NavigationStack { OTEditor(original: .nueva(), nueva: true) } }
            .onAppear(perform: aplicarPeticion)
            .onChange(of: estado.filtroOrdenes) { aplicarPeticion() }
            .onChange(of: estado.abrirOT) { aplicarPeticion() }
        }
    }

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Vista", selection: $vista) {
                Text("Pendientes \(almacen.pendientes.count)").tag(VistaOrdenes.pendientes)
                Text("Histórico \(almacen.historico.count)").tag(VistaOrdenes.historico)
                Text("Canceladas").tag(VistaOrdenes.canceladas)
            }
            .pickerStyle(.segmented)
            if vista == .pendientes {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([FiltroRapido.todos, .hoy, .sinAsignar, .vencidos]) { f in
                            Button { withAnimation { rapido = f } } label: {
                                Text(f.etiqueta).font(.app(.subheadline, .medium))
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .foregroundStyle(rapido == f ? Color.white : Color.primary)
                                    .background(rapido == f ? Color.pMorado : Color.gray.opacity(0.12), in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .textCase(nil)
    }

    private func aplicarPeticion() {
        if let f = estado.filtroOrdenes {
            if f == .historico { vista = .historico } else { vista = .pendientes; rapido = f }
            estado.filtroOrdenes = nil
        }
        if let id = estado.abrirOT {
            estado.abrirOT = nil
            ruta.append(id)
        }
    }
}

/// Menú para asignar técnico a una OT (fila, deslizar o ficha).
struct MenuAsignar: View {
    @Environment(Almacen.self) private var almacen
    let ot: OrdenTrabajo

    var body: some View {
        Menu {
            Button {
                if let w = almacen.masAdecuado(grupo: ot.grupoId) { Task { await almacen.asignar(ot, a: [w.id]) } }
            } label: { Label("El más adecuado", systemImage: "sparkles") }
            Divider()
            ForEach(almacen.tecnicos.filter(\.activo)) { w in
                Button { Task { await almacen.asignar(ot, a: [w.id]) } } label: {
                    Label(w.nombreCompleto, systemImage: ot.tecnicoIds.contains(w.id) ? "checkmark" : "person")
                }
            }
            if !ot.tecnicoIds.isEmpty {
                Divider()
                Button(role: .destructive) { Task { await almacen.asignar(ot, a: []) } } label: {
                    Label("Sin asignar", systemImage: "person.crop.circle.badge.xmark")
                }
            }
        } label: {
            Label("Asignar", systemImage: "person.badge.plus")
        }
        .tint(.pMorado)
    }
}
