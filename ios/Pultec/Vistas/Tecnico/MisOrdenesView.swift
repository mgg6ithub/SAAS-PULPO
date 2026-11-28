import SwiftUI

/// Técnico: «¿En qué activos vas a trabajar?» y Mis órdenes (Atrasadas · Hoy · Otros días).
struct MisOrdenesView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(AppEstado.self) private var estado
    @AppStorage("otrosDiasAbierto") private var otrosAbierto = true
    @State private var eligiendo = false
    @State private var buscar = ""
    @State private var crearIncidencia = false
    @State private var ruta = NavigationPath()
    @State private var avisoCerrado: Set<String> = []

    private var yo: String { almacen.tecnicoActivo ?? "" }

    var body: some View {
        NavigationStack(path: $ruta) {
            Group {
                if eligiendo { ElegirActivosView { eligiendo = false } }
                else { lista }
            }
            .fondoTema()
            .navigationDestination(for: String.self) { OTTecnicoView(otId: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { MenuPerfilTecnico() }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { crearIncidencia = true } label: { Image(systemName: "exclamationmark.circle.fill") }
                        .tint(.pRojo).accessibilityLabel(Text("Crear incidencia"))
                    BotonAvisos()
                }
            }
            .sheet(isPresented: $crearIncidencia) { CrearIncidenciaView(incidencia: .nueva(tecnico: yo)) }
            .onAppear {
                eligiendo = !UserDefaults.standard.bool(forKey: "eligio-\(yo)-\(Fechas.texto(Fechas.hoy))")
                abrirPedida()
            }
            .onChange(of: estado.abrirOT) { abrirPedida() }
        }
    }

    private func abrirPedida() {
        if let id = estado.abrirOT { estado.abrirOT = nil; eligiendo = false; ruta.append(id) }
    }

    private var mias: [OrdenTrabajo] {
        let l = almacen.misOrdenes(yo)
        guard !buscar.isEmpty else { return l }
        return l.filter { $0.nombre.localizedCaseInsensitiveContains(buscar) || (almacen.activo($0.activoId)?.nombreCompleto.localizedCaseInsensitiveContains(buscar) ?? false) }
    }

    private var lista: some View {
        let atrasadas = mias.filter(\.vencida)
        let hoy = mias.filter { $0.paraHoy || ($0.estado == .enCurso && !$0.vencida) }
        let otros = mias.filter { !$0.vencida && !$0.paraHoy && $0.estado != .enCurso }
        let semana = mias.filter { ($0.proximo ?? .distantFuture) <= Fechas.mas(Fechas.hoy, dias: 7) && !$0.vencida }.count
        return List {
            Section {} header: {
                VStack(alignment: .leading, spacing: 14) {
                    Text(Fechas.larga(Date())).font(.app(.subheadline, .medium)).foregroundStyle(Color.pMorado)
                    HStack {
                        Text("Hola, \(almacen.tecnico(yo)?.nombre ?? "")").font(.system(size: 30, weight: .bold)).foregroundStyle(Color.primary)
                        Spacer()
                        Button { withAnimation { eligiendo = true } } label: {
                            Label("\(almacen.tecnico(yo)?.activosElegidos.count ?? 0) activos", image: "IconoActivos")
                        }
                        .buttonStyle(.glass).controlSize(.small)
                    }
                    HStack(spacing: 10) {
                        cifra(hoy.count, "Para hoy", "calendar", .pMorado)
                        cifra(atrasadas.count, "Atrasadas", "exclamationmark.triangle", .pRojo)
                        cifra(semana, "Esta semana", "calendar.badge.clock", .pVerde)
                    }
                    ForEach(almacen.avisos.filter { !avisoCerrado.contains($0.id) && !almacen.leidos.contains($0.id) }) { a in
                        HStack(alignment: .top, spacing: 8) {
                            Insignia(texto: "Nuevo", color: .pMorado, punto: false)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(a.titulo).font(.app(.subheadline, .medium)).foregroundStyle(Color.primary)
                                Text(a.detalle).font(.app(.caption)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { avisoCerrado.insert(a.id); almacen.leidos.insert(a.id) } label: { Image(systemName: "xmark").font(.caption.bold()) }
                                .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel(Text("Cerrar aviso"))
                        }
                        .padding(12)
                        .background(Color.pMorado.opacity(0.07), in: .rect(cornerRadius: 12, style: .continuous))
                    }
                }
                .textCase(nil)
            }
            grupo("Atrasadas", atrasadas, color: .pRojo, vacio: nil)
            grupo("Hoy", hoy, color: .pMorado, vacio: "Hoy no tienes órdenes.")
            if !otros.isEmpty {
                Section(isExpanded: $otrosAbierto) {
                    ForEach(otros) { o in NavigationLink(value: o.id) { FilaOT(ot: o, mostrarTecnico: false) } }
                } header: {
                    HStack(spacing: 6) { Punto(color: .gray); Text("Otros días \(otros.count)") }
                }
            }
            if mias.isEmpty {
                Section {} header: {
                    EstadoVacio(icono: "line.3.horizontal.decrease", titulo: "No tienes órdenes pendientes con estos filtros",
                                mensaje: "Prueba a cambiar los activos o la búsqueda.").textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $buscar, prompt: "Buscar…")
        .refreshable { await almacen.recargar() }
        .navigationTitle("Mis órdenes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func cifra(_ n: Int, _ t: LocalizedStringKey, _ icono: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icono).font(.system(size: 13, weight: .semibold)).foregroundStyle(c)
                .frame(width: 28, height: 28).background(c.opacity(0.13), in: .rect(cornerRadius: 8, style: .continuous))
            Text("\(n)").font(.system(size: 22, weight: .semibold)).foregroundStyle(Color.primary)
            Text(t).font(.app(.caption)).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func grupo(_ titulo: LocalizedStringKey, _ l: [OrdenTrabajo], color: Color, vacio: LocalizedStringKey?) -> some View {
        if !l.isEmpty || vacio != nil {
            Section {
                ForEach(l) { o in NavigationLink(value: o.id) { FilaOT(ot: o, mostrarTecnico: false) } }
                if l.isEmpty, let vacio { Text(vacio).font(.app(.subheadline)).foregroundStyle(.secondary) }
            } header: {
                HStack(spacing: 6) { Punto(color: color); Text(titulo); Text("\(l.count)").foregroundStyle(.secondary) }
            }
        }
    }
}

/// «¿En qué activos vas a trabajar?»: solo verá las órdenes de los que marque.
struct ElegirActivosView: View {
    @Environment(Almacen.self) private var almacen
    let alTerminar: () -> Void
    @State private var marcados: Set<String> = []

    private var yo: String { almacen.tecnicoActivo ?? "" }
    private var conOrdenes: [(Activo, Int)] {
        let mias = almacen.pendientes.filter { $0.tecnicoIds.contains(yo) }
        let por = Dictionary(grouping: mias, by: { almacen.raiz($0.activoId)?.id ?? "" })
        return almacen.raices.compactMap { a in por[a.id].map { (a, $0.count) } }
    }

    var body: some View {
        List {
            Section {} header: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Fechas.larga(Date())).font(.app(.subheadline, .medium)).foregroundStyle(Color.pMorado)
                    Text("Hola, \(almacen.tecnico(yo)?.nombre ?? "")").font(.system(size: 30, weight: .bold)).foregroundStyle(Color.primary)
                    Text("¿En qué activos vas a trabajar?").font(.app(.title3, .semibold)).foregroundStyle(Color.primary)
                    Text("Solo verás las órdenes de los que marques. Puedes cambiarlo cuando quieras.").font(.app(.subheadline)).foregroundStyle(.secondary)
                }
                .textCase(nil)
            }
            Section {
                ForEach(conOrdenes, id: \.0.id) { a, n in
                    Button {
                        if marcados.contains(a.id) { marcados.remove(a.id) } else { marcados.insert(a.id) }
                    } label: {
                        HStack(spacing: 12) {
                            IconoActivo(clave: a.icono)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(a.nombreCompleto).font(.app(.body, .semibold)).foregroundStyle(Color.primary)
                                Text(n == 1 ? "Una orden" : "\(n) órdenes").font(.app(.caption)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: marcados.contains(a.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title2).foregroundStyle(marcados.contains(a.id) ? Color.pMorado : .secondary)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: marcados.contains(a.id))
                }
            } header: {
                HStack {
                    Spacer()
                    Button(marcados.count == conOrdenes.count ? "Quitar todos" : "Marcar todos") {
                        marcados = marcados.count == conOrdenes.count ? [] : Set(conOrdenes.map(\.0.id))
                    }
                    .font(.app(.caption, .medium)).textCase(nil)
                }
            }
            if conOrdenes.isEmpty {
                Section {} header: { EstadoVacio(icono: "checkmark.circle", titulo: "No tienes órdenes asignadas").textCase(nil) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            let n = almacen.pendientes.filter { $0.tecnicoIds.contains(yo) && marcados.contains(almacen.raiz($0.activoId)?.id ?? "") }.count
            Button {
                Task {
                    await almacen.guardarActivosElegidos(yo, Array(marcados))
                    UserDefaults.standard.set(true, forKey: "eligio-\(yo)-\(Fechas.texto(Fechas.hoy))")
                    withAnimation { alTerminar() }
                }
            } label: {
                Text(n == 1 ? "Empezar con una orden" : "Empezar con \(n) órdenes").font(.app(.body, .semibold)).frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(marcados.isEmpty)
            .padding(16)
        }
        .navigationTitle("Activos")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let elegidos = Set(almacen.tecnico(yo)?.activosElegidos ?? [])
            marcados = elegidos.isEmpty ? Set(conOrdenes.map(\.0.id)) : elegidos
        }
    }
}

/// Avatar arriba a la izquierda: Mi perfil, volver a la vista de administrador y cerrar sesión.
struct MenuPerfilTecnico: View {
    @Environment(Almacen.self) private var almacen
    @State private var perfil = false

    var body: some View {
        Menu {
            Button { perfil = true } label: { Label("Mi perfil", systemImage: "person.crop.circle") }
            if almacen.esAdmin {
                Button { withAnimation { almacen.viendoComo = nil } } label: { Label("Vista de administrador", systemImage: "arrow.left.arrow.right") }
            }
            Button(role: .destructive) { Task { await almacen.salir() } } label: { Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right") }
        } label: {
            Avatar(tecnico: almacen.tecnico(almacen.tecnicoActivo), tamano: 30, conEstado: true)
        }
        .sheet(isPresented: $perfil) { PerfilTecnicoView() }
    }
}
