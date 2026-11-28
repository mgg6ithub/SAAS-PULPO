import SwiftUI

/// Técnicos: Todos · Disponibles · Ocupados · Ausentes, agrupados por grupo; tocar → ficha.
struct TecnicosView: View {
    @Environment(Almacen.self) private var almacen
    @State private var filtro: EstadoHoy?
    @State private var buscar = ""
    @State private var nuevo = false
    @State private var grupo: Grupo?
    @State private var nuevoGrupo = false

    private func filtrar(_ l: [Tecnico]) -> [Tecnico] {
        l.filter { w in
            (filtro == nil || w.estadoHoy == filtro) && (buscar.isEmpty || w.nombreCompleto.localizedCaseInsensitiveContains(buscar))
        }
    }

    var body: some View {
        Pila {
            ListaRelieve {
                Section {} header: {
                    Picker("Estado", selection: $filtro) {
                        Text("Todos").tag(EstadoHoy?.none)
                        ForEach(EstadoHoy.allCases, id: \.self) { e in
                            Text(e == .disponible ? "Disponibles" : e == .ocupado ? "Ocupados" : "Ausentes").tag(EstadoHoy?.some(e))
                        }
                    }
                    .pickerStyle(.segmented)
                }
                ForEach(almacen.grupos) { g in
                    let miembros = filtrar(almacen.tecnicos.filter { $0.grupoIds.contains(g.id) })
                    if !miembros.isEmpty || buscar.isEmpty {
                        Section {
                            ForEach(miembros) { fila($0) }
                        } header: {
                            HStack {
                                Label("\(g.nombre) \(miembros.count)", systemImage: "person.3")
                                Spacer()
                                Button("Editar") { grupo = g }.font(.app(.caption, .medium)).textCase(nil)
                            }
                        }
                    }
                }
                let sinGrupo = filtrar(almacen.tecnicos.filter { $0.grupoIds.isEmpty })
                if !sinGrupo.isEmpty {
                    Section(almacen.grupos.isEmpty ? "Técnicos" : "Sin grupo \(sinGrupo.count)") {
                        ForEach(sinGrupo) { fila($0) }
                    }
                }
                if almacen.tecnicos.isEmpty {
                    Section {} header: { EstadoVacio(icono: "person.2", titulo: "Aún no hay técnicos", mensaje: "Añade el primero con el botón +.").textCase(nil) }
                }
            }
            .searchable(text: $buscar, prompt: "Buscar técnico o grupo…")
            .refreshable { await almacen.recargar() }
            .fondoTema()
            .tituloPantalla("Técnicos", icono: "person.2")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink { AccesosView() } label: { Image(systemName: "key") }
                        .accessibilityLabel(Text("Accesos"))
                    Menu {
                        Button { nuevo = true } label: { Label("Técnico", systemImage: "person.badge.plus") }
                        Button { nuevoGrupo = true } label: { Label("Grupo", systemImage: "person.3") }
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel(Text("Añadir"))
                }
            }
            .sheet(isPresented: $nuevo) { NavigationStack { TecnicoForm(original: .nuevo(), nuevo: true) } }
            .sheet(item: $grupo) { g in NavigationStack { GrupoForm(id: g.id, nombre: g.nombre, nuevo: false) } }
            .sheet(isPresented: $nuevoGrupo) { NavigationStack { GrupoForm(id: UUID().uuidString.lowercased(), nombre: "", nuevo: true) } }
        }
    }

    private func fila(_ w: Tecnico) -> some View {
        NavigationLink { TecnicoDetalleView(tecnicoId: w.id) } label: {
            HStack(spacing: 12) {
                Avatar(tecnico: w, tamano: 38, conEstado: true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(w.nombreCompleto).font(.app(.body, .semibold))
                    let n = almacen.ordenesDe(tecnico: w.id).filter(\.estado.abierta).count
                    Text(n == 1 ? "Una orden de trabajo" : "\(n) órdenes de trabajo").font(.app(.caption)).foregroundStyle(.secondary)
                }
                Spacer()
                let atrasadas = almacen.ordenesDe(tecnico: w.id).filter(\.vencida).count
                if atrasadas > 0 {
                    Text("\(atrasadas)").font(.app(.caption, .bold)).foregroundStyle(.white)
                        .frame(minWidth: 22, minHeight: 22).background(Color.pRojo, in: .circle)
                        .accessibilityLabel(Text("\(atrasadas) atrasadas"))
                }
                Insignia(texto: w.estadoHoy.etiqueta, color: w.estadoHoy.color)
            }
        }
    }
}

/// Ficha del técnico: estado de hoy, sus órdenes (Pendientes / Histórico), asignar orden e invitar.
struct TecnicoDetalleView: View {
    @Environment(Almacen.self) private var almacen
    let tecnicoId: String
    @State private var historico = false
    @State private var editar = false
    @State private var asignar = false
    @State private var enlace: URL?

    var body: some View {
        if let w = almacen.tecnico(tecnicoId) {
            let todas = almacen.ordenesDe(tecnico: w.id)
            let lista = historico ? todas.filter { !$0.estado.abierta } : todas.filter(\.estado.abierta).sorted(by: Almacen.porFecha)
            ListaRelieve {
                Section {} header: {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            Avatar(tecnico: w, tamano: 56, conEstado: true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(w.nombreCompleto).font(.system(size: 22, weight: .bold)).foregroundStyle(Color.primary)
                                Text(w.grupoIds.compactMap { almacen.grupo($0)?.nombre }.joined(separator: ", ").ifEmpty(String(localized: "Sin grupo")))
                                    .font(.app(.subheadline)).foregroundStyle(.secondary)
                            }
                        }
                        Menu {
                            ForEach(EstadoHoy.allCases, id: \.self) { e in
                                Button { Task { await almacen.cambiarEstadoHoy(w, e) } } label: {
                                    Label(e.etiqueta, systemImage: w.estadoHoy == e ? "checkmark" : "circle.fill")
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("Hoy")
                                Insignia(texto: w.estadoHoy.etiqueta, color: w.estadoHoy.color)
                                Image(systemName: "chevron.up.chevron.down").font(.caption2)
                            }
                        }
                        HStack(spacing: 10) {
                            Button { asignar = true } label: { Label("Asignar orden", systemImage: "plus") }.buttonStyle(.glassProminent)
                            Button {
                                Task { enlace = await almacen.invitar(w) }
                            } label: { Label("Invitar a la app", systemImage: "paperplane") }.buttonStyle(.glass)
                        }
                        if let enlace {
                            ShareLink(item: enlace, message: Text("Entra en Pultec con tu cuenta y verás tus órdenes de trabajo.")) {
                                Label("Enviar enlace de invitación", systemImage: "square.and.arrow.up")
                            }
                            Text("Mándalo por WhatsApp o correo. Vale una sola vez y caduca en 7 días.").font(.app(.caption)).foregroundStyle(.secondary)
                        }
                        Picker("Órdenes", selection: $historico) {
                            Text("Pendientes \(todas.filter(\.estado.abierta).count)").tag(false)
                            Text("Histórico").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                    .textCase(nil)
                }
                Section {
                    ForEach(lista) { o in NavigationLink { OTDetalleView(otId: o.id) } label: { FilaOT(ot: o, mostrarTecnico: false) } }
                } footer: {
                    if lista.isEmpty { Text(historico ? "Aún no ha cerrado órdenes." : "No tiene órdenes de trabajo pendientes.") }
                }
            }
            .fondoTema()
            .navigationTitle(w.nombreCompleto)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editar = true } label: { Image(systemName: "pencil") }.accessibilityLabel(Text("Editar"))
                }
            }
            .sheet(isPresented: $editar) { NavigationStack { TecnicoForm(original: w, nuevo: false) } }
            .sheet(isPresented: $asignar) { AsignarOrdenView(tecnico: w) }
        } else {
            EstadoVacio(icono: "person", titulo: "Este técnico ya no existe").fondoTema()
        }
    }
}

/// «Asignar orden»: OT sin técnico para dárselas (las que se solapan no se pueden elegir).
struct AsignarOrdenView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var dismiss
    let tecnico: Tecnico

    var body: some View {
        NavigationStack {
            let libres = almacen.pendientes.filter { $0.tecnicoIds.isEmpty }
            ListaRelieve {
                Section {
                    ForEach(libres.prefix(200)) { o in
                        Button { Task { await almacen.asignar(o, a: [tecnico.id]); dismiss() } } label: { FilaOT(ot: o, mostrarTecnico: false) }
                            .buttonStyle(.plain)
                    }
                } footer: { Text("Toca una orden de trabajo para asignársela.") }
                if libres.isEmpty {
                    Section {} header: { EstadoVacio(icono: "checkmark.circle", titulo: "Todas las órdenes tienen técnico").textCase(nil) }
                }
            }
            .fondoTema()
            .hojaConsulta(tecnico.nombreCompleto)
        }
    }
}

struct TecnicoForm: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var dismiss
    let original: Tecnico
    let nuevo: Bool
    @State private var w: Tecnico

    init(original: Tecnico, nuevo: Bool) {
        self.original = original
        self.nuevo = nuevo
        _w = State(initialValue: original)
    }

    var body: some View {
        ListaRelieve {
            Section {
                TextField("Nombre", text: $w.nombre)
                TextField("Apellidos", text: $w.apellidos)
                TextField("Teléfono", text: $w.telefono).keyboardType(.phonePad)
                TextField("Email", text: $w.email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                HStack(spacing: 10) {
                    ForEach(Tecnico.colores.indices, id: \.self) { c in
                        Circle().fill(Color(hex: Tecnico.colores[c])).frame(width: 28, height: 28)
                            .overlay { if w.color == c { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) } }
                            .onTapGesture { w.color = c }
                    }
                }
                .padding(.vertical, 4)
            } header: { Text("Datos personales") } footer: { Text("Nombre y forma de contacto.") }
            Section("Disponibilidad") {
                Picker("Hoy", selection: $w.estadoHoy) {
                    ForEach(EstadoHoy.allCases, id: \.self) { Text($0.etiqueta).tag($0) }
                }
                Toggle(isOn: $w.activo) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Activo")
                        Text("Si está de baja o ya no trabaja, desactívalo.").font(.app(.caption)).foregroundStyle(.secondary)
                    }
                }
            }
            if !almacen.grupos.isEmpty {
                Section("Grupos") {
                    ForEach(almacen.grupos) { g in
                        Toggle(g.nombre, isOn: Binding(get: { w.grupoIds.contains(g.id) }, set: { v in
                            if v { w.grupoIds.append(g.id) } else { w.grupoIds.removeAll { $0 == g.id } }
                        }))
                    }
                }
            }
            Section("Notas") {
                TextField("Turno, zona o equipo de mantenimiento", text: $w.info, axis: .vertical).lineLimit(1...4)
            }
        }
        .fondoTema()
        .hojaFormulario(nuevo ? String(localized: "Nuevo técnico") : w.nombreCompleto, puedeGuardar: !w.nombre.isEmpty && (nuevo || w != original)) {
            Task { await almacen.guardar(w); dismiss() }
        }
    }
}

struct GrupoForm: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var dismiss
    let id: String
    let nuevo: Bool
    @State private var nombre: String
    @State private var miembros: Set<String> = []
    @State private var borrar = false

    init(id: String, nombre: String, nuevo: Bool) {
        self.id = id
        self.nuevo = nuevo
        _nombre = State(initialValue: nombre)
    }

    var body: some View {
        ListaRelieve {
            Section("Grupo") { TextField("Nombre (Hidráulica A)", text: $nombre) }
            Section {
                ForEach(almacen.tecnicos.filter(\.activo)) { w in
                    Button {
                        if miembros.contains(w.id) { miembros.remove(w.id) } else { miembros.insert(w.id) }
                    } label: {
                        HStack {
                            Avatar(tecnico: w, tamano: 26)
                            Text(w.nombreCompleto).foregroundStyle(Color.primary)
                            Spacer()
                            if miembros.contains(w.id) { Image(systemName: "checkmark").foregroundStyle(Color.pMorado) }
                        }
                    }
                }
            } header: { Text("Técnicos") } footer: { Text("Un técnico puede estar en varios grupos. Lo que se asigna al grupo va al más libre.") }
            if !nuevo {
                Section { Button(role: .destructive) { borrar = true } label: { Label("Borrar grupo", systemImage: "trash") }.foregroundStyle(.red) }
            }
        }
        .fondoTema()
        .hojaFormulario(nuevo ? String(localized: "Nuevo grupo") : nombre, puedeGuardar: !nombre.isEmpty) {
            Task { await almacen.guardarGrupo(id: id, nombre: nombre, miembros: miembros); dismiss() }
        }
        .onAppear { miembros = Set(almacen.tecnicos.filter { $0.grupoIds.contains(id) }.map(\.id)) }
        .confirmationDialog("¿Borrar el grupo?", isPresented: $borrar) {
            Button("Borrar", role: .destructive) {
                if let g = almacen.grupo(id) { Task { await almacen.borrarGrupo(g); dismiss() } }
            }
        }
    }
}

/// Accesos: quién entra con cuenta y técnicos sin cuenta (Invitar).
struct AccesosView: View {
    @Environment(Almacen.self) private var almacen
    @State private var enlaces: [String: URL] = [:]

    var body: some View {
        ListaRelieve {
            Section("Con acceso") {
                Label(almacen.correo, systemImage: "person.crop.circle.badge.checkmark")
                    .badge(Text("Administrador"))
            }
            Section {
                ForEach(almacen.tecnicos.filter(\.activo)) { w in
                    HStack {
                        Avatar(tecnico: w, tamano: 30)
                        VStack(alignment: .leading) {
                            Text(w.nombreCompleto)
                            if !w.email.isEmpty { Text(w.email).font(.app(.caption)).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        if let url = enlaces[w.id] {
                            ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                        } else {
                            Button("Invitar") { Task { enlaces[w.id] = await almacen.invitar(w) } }.font(.app(.subheadline, .medium))
                        }
                    }
                }
            } header: { Text("Técnicos") } footer: { Text("Cada técnico entra con su propia cuenta y solo ve sus órdenes de trabajo.") }
        }
        .fondoTema()
        .navigationTitle("Accesos")
    }
}

extension String {
    func ifEmpty(_ otro: String) -> String { isEmpty ? otro : self }
}
