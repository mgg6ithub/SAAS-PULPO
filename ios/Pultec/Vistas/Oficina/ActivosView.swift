import SwiftUI

/// Activos: lista de máquinas principales con buscador; tocar → activo.
struct ActivosView: View {
    @Environment(Almacen.self) private var almacen
    @State private var buscar = ""
    @State private var nuevo = false
    @State private var borrar: Activo?

    private var lista: [Activo] {
        buscar.isEmpty ? almacen.raices
            : almacen.activos.filter { $0.nombreCompleto.localizedCaseInsensitiveContains(buscar) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(lista) { a in
                        NavigationLink { ActivoDetalleView(activoId: a.id) } label: { FilaActivo(activo: a) }
                            .swipeActions {
                                Button(role: .destructive) { borrar = a } label: { Label("Borrar", systemImage: "trash") }
                            }
                    }
                } footer: {
                    Text(lista.count == 1 ? "Un activo" : "\(lista.count) activos").frame(maxWidth: .infinity)
                }
                if almacen.activos.isEmpty {
                    Section {} header: {
                        EstadoVacio(icono: "IconoActivos", titulo: "Aún no hay activos", mensaje: "Crea tu primera máquina con el botón +.").textCase(nil)
                    }
                }
            }
            .searchable(text: $buscar, prompt: "Buscar activo…")
            .refreshable { await almacen.recargar() }
            .fondoTema()
            .tituloPantalla("Activos", icono: "IconoActivos")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { nuevo = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel(Text("Activo")).keyboardShortcut("n", modifiers: [])
                    BotonAvisos()
                }
            }
            .sheet(isPresented: $nuevo) { NavigationStack { ActivoForm(original: .nuevo(), nuevo: true) } }
            .confirmationDialog(borrar.map { "¿Borrar \($0.nombreCompleto)?" } ?? "", isPresented: Binding(get: { borrar != nil }, set: { if !$0 { borrar = nil } }),
                                titleVisibility: .visible, presenting: borrar) { a in
                Button("Borrar", role: .destructive) { Task { await almacen.borrar(activo: a) } }
            } message: { _ in
                Text("Se borran también sus componentes, mantenimientos, órdenes de trabajo e incidencias.")
            }
        }
    }
}

/// Activo por dentro: ruta, resumen, Vista general (Mantenimientos / Componentes),
/// Información (ficha) y Órdenes de trabajo. Los componentes usan esta misma vista.
struct ActivoDetalleView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var dismiss
    let activoId: String
    @State private var pestana = 0
    @State private var parte = 0
    @State private var nuevoPlan = false
    @State private var nuevoComponente = false
    @State private var nuevaOT = false
    @State private var editarPlan: PlanMantenimiento?
    @State private var confirmarBorrar = false
    @State private var historico = false

    var body: some View {
        if let a = almacen.activo(activoId) {
            contenido(a)
        } else {
            EstadoVacio(icono: "IconoActivos", titulo: "Este activo ya no existe").fondoTema()
        }
    }

    private func contenido(_ a: Activo) -> some View {
        List {
            Section {} header: { cabecera(a) }
            switch pestana {
            case 0: vistaGeneral(a)
            case 1: ActivoCampos(original: a).id(a.id)
            default: ordenes(a)
            }
        }
        .fondoTema()
        .navigationTitle(a.nombreCompleto)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button { nuevoPlan = true } label: { Label("Mantenimiento", systemImage: "doc.badge.plus") }
                    Button { nuevoComponente = true } label: { Label("Componente", systemImage: "square.stack.3d.up") }
                    Button { nuevaOT = true } label: { Label("Orden de trabajo", systemImage: "list.clipboard") }
                } label: { Image(systemName: "plus") }
                .accessibilityLabel(Text("Añadir"))
                Menu {
                    Button(role: .destructive) { confirmarBorrar = true } label: { Label("Borrar activo", systemImage: "trash") }
                } label: { Image(systemName: "trash") }
                .tint(.red)
            }
        }
        .sheet(isPresented: $nuevoPlan) { NavigationStack { PlanForm(original: .nuevo(activo: a.id), nuevo: true) } }
        .sheet(item: $editarPlan) { p in NavigationStack { PlanForm(original: p, nuevo: false) } }
        .sheet(isPresented: $nuevoComponente) { NavigationStack { ActivoForm(original: .nuevo(padre: a.id), nuevo: true) } }
        .sheet(isPresented: $nuevaOT) { NavigationStack { OTEditor(original: .nueva(activo: a.id), nueva: true) } }
        .confirmationDialog("¿Borrar \(a.nombreCompleto)?", isPresented: $confirmarBorrar, titleVisibility: .visible) {
            Button("Borrar", role: .destructive) { Task { await almacen.borrar(activo: a); dismiss() } }
        } message: { Text("Se borran también sus componentes, mantenimientos, órdenes de trabajo e incidencias.") }
    }

    private func cabecera(_ a: Activo) -> some View {
        let ruta = almacen.ruta(a.id)
        let planes = almacen.planesConComponentes(a.id)
        let proximo = planes.compactMap { p in almacen.otAbierta(de: p).map { (p, $0) } }.min { ($0.1.proximo ?? .distantFuture) < ($1.1.proximo ?? .distantFuture) }
        let abiertas = almacen.incidencias.filter { $0.estado == .abierta && almacen.arbol(a.id).contains($0.activoId) }.count
        return VStack(alignment: .leading, spacing: 12) {
            if ruta.count > 1 {
                Text(ruta.dropLast().map(\.nombre).joined(separator: " / ")).font(.app(.caption)).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                IconoActivo(clave: a.icono, tamano: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(a.nombreCompleto).font(.system(size: 22, weight: .bold)).foregroundStyle(Color.primary)
                    let ficha = [a.fabricante, a.modelo].filter { !$0.isEmpty }.joined(separator: " ")
                    if !ficha.isEmpty { Text(ficha).font(.app(.subheadline)).foregroundStyle(.secondary) }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                if let (p, o) = proximo, let f = o.proximo {
                    Text("Próximo \(Fechas.relativo(f)): \(p.nombre), \(Fechas.corta(f))").foregroundStyle(f < Fechas.hoy ? Color.pRojo : Color.secondary)
                }
                let raiz = almacen.raiz(a.id) ?? a
                Text("Contador \(Int(raiz.horasHoy)) h, +\(Int(raiz.usoHoras)) h al día")
                Text("Órdenes pendientes \(almacen.ordenesDe(activo: a.id).filter(\.estado.abierta).count)")
            }
            .font(.app(.subheadline)).foregroundStyle(.secondary)
            if abiertas > 0 {
                Insignia(texto: abiertas == 1 ? "Una incidencia abierta" : "\(abiertas) incidencias abiertas", color: .pRojo, icono: "exclamationmark.circle")
            }
            Picker("Vista", selection: $pestana.animation()) {
                Text("Vista general").tag(0)
                Text("Información").tag(1)
                Text("Órdenes").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.top, 4)
        }
        .textCase(nil)
    }

    @ViewBuilder
    private func vistaGeneral(_ a: Activo) -> some View {
        let planes = almacen.planesConComponentes(a.id)
        let hijos = almacen.hijos(a.id)
        Section {} header: {
            Picker("Parte", selection: $parte) {
                Text("Mantenimientos \(planes.count)").tag(0)
                Text(a.padreId == nil ? "Componentes \(hijos.count)" : "Subcomponentes \(hijos.count)").tag(1)
            }
            .pickerStyle(.segmented)
        }
        if parte == 0 {
            Section {
                ForEach(planes) { p in
                    Button { editarPlan = p } label: { FilaPlan(plan: p) }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button { Task { await almacen.pausar(p, p.activa) } } label: {
                                Label(p.activa ? "Pausar" : "Reanudar", systemImage: p.activa ? "pause" : "play")
                            }
                            .tint(.pAmbar)
                        }
                }
            } footer: {
                if planes.isEmpty { Text("Sin mantenimientos. Añade uno con + y Pultec creará sus órdenes solo.") }
            }
        } else {
            Section {
                ForEach(hijos) { h in
                    NavigationLink { ActivoDetalleView(activoId: h.id) } label: { FilaActivo(activo: h) }
                }
            } footer: {
                if hijos.isEmpty { Text("Sin componentes.") }
            }
        }
    }

    @ViewBuilder
    private func ordenes(_ a: Activo) -> some View {
        let todas = almacen.ordenesDe(activo: a.id)
        let lista = historico ? todas.filter { !$0.estado.abierta } : todas.filter(\.estado.abierta).sorted(by: Almacen.porFecha)
        Section {} header: {
            VStack(spacing: 10) {
                Consejo("¿Se repite cada cierto tiempo? Crea un mantenimiento y Pultec creará su orden de trabajo cada vez que toque.", clave: "activo-ot")
                Picker("Órdenes", selection: $historico) {
                    Text("Pendientes").tag(false)
                    Text("Histórico").tag(true)
                }
                .pickerStyle(.segmented)
            }
        }
        Section {
            ForEach(lista) { o in NavigationLink { OTDetalleView(otId: o.id) } label: { FilaOT(ot: o) } }
        } footer: {
            if lista.isEmpty { Text(historico ? "Aún no hay órdenes cerradas." : "No tiene órdenes pendientes.") }
        }
    }
}

/// Fila de mantenimiento: anillo de ciclo, nombre, vigencia, OT (estado, fecha y técnico) y cada cuánto.
struct FilaPlan: View {
    @Environment(Almacen.self) private var almacen
    let plan: PlanMantenimiento

    var body: some View {
        let ot = almacen.otAbierta(de: plan)
        HStack(alignment: .top, spacing: 12) {
            AnilloCiclo(valor: almacen.ciclo(plan)).padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.nombre).font(.app(.body, .semibold))
                if let a = almacen.activo(plan.activoId), a.padreId != nil {
                    Text(a.nombreCompleto).font(.app(.caption)).foregroundStyle(.secondary).lineLimit(1)
                }
                if !plan.descripcion.isEmpty { Text(plan.descripcion).font(.app(.caption)).foregroundStyle(.secondary).lineLimit(1) }
                HStack(spacing: 6) {
                    Insignia(texto: plan.activa ? "Activo" : "Pausado", color: plan.activa ? .pVerde : .secondary,
                             icono: plan.activa ? "play.fill" : "pause.fill")
                    if let ot, let f = ot.proximo {
                        Insignia(texto: "\(Fechas.dm(f))", color: ot.vencida ? .pRojo : .pMorado,
                                 icono: ot.vencida ? "exclamationmark.triangle" : "calendar")
                    }
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Text(plan.cadaCuanto).font(.app(.caption)).foregroundStyle(.secondary)
                if let ot { Avatar(tecnico: almacen.tecnico(ot.tecnicoIds.first), tamano: 24) }
            }
        }
        .contentShape(.rect)
    }
}
