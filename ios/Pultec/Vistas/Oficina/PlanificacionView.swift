import SwiftUI

/// Planificación: calendario de las OT en Mes, Semana y Día.
/// iPhone: mes compacto con puntos y la lista del día elegido debajo (como Calendario).
/// Mover una OT: mantener pulsado → «Mover a…» o «Asignar a…».
struct PlanificacionView: View {
    @Environment(Almacen.self) private var almacen
    @State private var modo = 0
    @State private var dia = Fechas.hoy
    @State private var completadas = false
    @State private var resumen: OrdenTrabajo?
    @State private var nueva = false

    private var cal: Calendar { var c = Calendar.current; c.firstWeekday = 2; return c }

    private func ordenes(_ d: Date) -> [OrdenTrabajo] {
        almacen.ordenes.filter { o in
            guard o.activa else { return false }
            if o.estado.abierta { return o.proximo.map { cal.isDate($0, inSameDayAs: d) } ?? false }
            return completadas && o.estado == .completada && (o.ultimo.map { cal.isDate($0, inSameDayAs: d) } ?? false)
        }
        .sorted(by: Almacen.porFecha)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {} header: { cabecera }
                switch modo {
                case 0: mes
                case 1: semana
                default: porTecnico
                }
            }
            .fondoTema()
            .tituloPantalla("Planificación", icono: "calendar")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { withAnimation { completadas.toggle() } } label: {
                        Image(systemName: completadas ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                    .accessibilityLabel(Text("Mostrar completadas"))
                    Button { siguienteConTrabajo() } label: { Image(systemName: "binoculars") }
                        .accessibilityLabel(Text("Siguiente día con trabajo"))
                    Button { nueva = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel(Text("Orden de trabajo"))
                }
            }
            .sheet(item: $resumen) { ResumenOT(ot: $0).presentationDetents([.medium, .large]) }
            .sheet(isPresented: $nueva) {
                NavigationStack { OTEditor(original: { var o = OrdenTrabajo.nueva(); o.proximo = dia; return o }(), nueva: true) }
            }
        }
    }

    private var cabecera: some View {
        VStack(spacing: 12) {
            HStack {
                Button { mover(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel(Text("Anterior"))
                Spacer()
                Text(titulo).font(.app(.headline)).foregroundStyle(Color.primary)
                Spacer()
                Button { mover(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel(Text("Siguiente"))
            }
            .buttonStyle(.glass)
            HStack {
                Picker("Vista", selection: $modo.animation()) {
                    Text("Mes").tag(0)
                    Text("Semana").tag(1)
                    Text("Día").tag(2)
                }
                .pickerStyle(.segmented)
                Button("Hoy") { withAnimation { dia = Fechas.hoy } }.buttonStyle(.glass)
            }
        }
        .textCase(nil)
    }

    private var titulo: String {
        switch modo {
        case 0: return dia.formatted(.dateTime.month(.wide).year()).capitalized
        case 1:
            let i = inicioSemana(dia)
            return String(localized: "Semana del \(i.formatted(.dateTime.day()))–\(Fechas.mas(i, dias: 6).formatted(.dateTime.day().month()))")
        default: return Fechas.frase(Fechas.larga(dia))
        }
    }

    private func inicioSemana(_ d: Date) -> Date { cal.dateInterval(of: .weekOfYear, for: d)?.start ?? d }

    private func mover(_ n: Int) {
        withAnimation {
            switch modo {
            case 0: dia = cal.date(byAdding: .month, value: n, to: dia) ?? dia
            case 1: dia = Fechas.mas(dia, dias: 7 * n)
            default: dia = Fechas.mas(dia, dias: n)
            }
        }
    }

    private func siguienteConTrabajo() {
        let futuras = almacen.pendientes.compactMap(\.proximo).filter { $0 > dia }.sorted()
        if let f = futuras.first { withAnimation { dia = f; modo = 2 } }
    }

    // MARK: Mes

    @ViewBuilder
    private var mes: some View {
        let inicio = cal.dateInterval(of: .month, for: dia)!.start
        let primero = inicioSemana(inicio)
        let dias = (0..<42).map { Fechas.mas(primero, dias: $0) }
        Section {
            VStack(spacing: 6) {
                HStack {
                    ForEach(["L", "M", "X", "J", "V", "S", "D"], id: \.self) {
                        Text(LocalizedStringKey($0)).font(.app(.caption2, .semibold)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                    ForEach(dias, id: \.self) { d in celda(d, delMes: cal.isDate(d, equalTo: dia, toGranularity: .month)) }
                }
            }
            .padding(.vertical, 6)
        }
        listaDia(dia)
    }

    private func celda(_ d: Date, delMes: Bool) -> some View {
        let lista = ordenes(d)
        let elegido = cal.isDate(d, inSameDayAs: dia)
        let hoy = cal.isDateInToday(d)
        return Button { withAnimation(.snappy) { dia = d } } label: {
            VStack(spacing: 3) {
                Text(d.formatted(.dateTime.day()))
                    .font(.app(.subheadline, hoy || elegido ? .bold : .regular))
                    .foregroundStyle(elegido ? Color.white : hoy ? Color.pMorado : delMes ? Color.primary : Color.secondary.opacity(0.5))
                    .frame(width: 32, height: 32)
                    .background(elegido ? Color.pMorado : .clear, in: .circle)
                HStack(spacing: 2) {
                    ForEach(Array(Set(lista.map(\.criticidad))).sorted { $0.rawValue < $1.rawValue }) { Punto(color: $0.color, tamano: 5) }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: elegido)
    }

    @ViewBuilder
    private func listaDia(_ d: Date) -> some View {
        let lista = ordenes(d)
        Section {
            ForEach(lista) { o in fila(o) }
        } header: {
            Text(Fechas.frase(Fechas.larga(d)))
        } footer: {
            if lista.isEmpty { Text("Sin órdenes este día.") }
        }
    }

    // MARK: Semana

    @ViewBuilder
    private var semana: some View {
        let i = inicioSemana(dia)
        ForEach(0..<7, id: \.self) { n in
            let d = Fechas.mas(i, dias: n)
            let lista = ordenes(d)
            Section {
                ForEach(lista) { o in fila(o) }
                if lista.isEmpty { Text("Sin órdenes").font(.app(.subheadline)).foregroundStyle(.tertiary) }
            } header: {
                HStack {
                    Text(Fechas.frase(Fechas.larga(d)))
                    if cal.isDateInToday(d) { Insignia(texto: "Hoy", color: .pMorado) }
                }
            }
        }
    }

    // MARK: Día por técnico

    @ViewBuilder
    private var porTecnico: some View {
        let lista = ordenes(dia)
        let sinTecnico = lista.filter { $0.tecnicoIds.isEmpty }
        ForEach(almacen.tecnicos.filter(\.activo)) { w in
            let suyas = lista.filter { $0.tecnicoIds.contains(w.id) }
            if !suyas.isEmpty {
                Section {
                    ForEach(suyas) { fila($0) }
                } header: {
                    HStack(spacing: 8) { Avatar(tecnico: w, tamano: 20); Text(w.nombreCompleto) }.textCase(nil)
                }
            }
        }
        if !sinTecnico.isEmpty {
            Section("Sin técnico") { ForEach(sinTecnico) { fila($0) } }
        }
        if lista.isEmpty {
            Section {} header: { EstadoVacio(icono: "calendar", titulo: "Nada programado este día").textCase(nil) }
        }
    }

    private func fila(_ o: OrdenTrabajo) -> some View {
        Button { resumen = o } label: {
            HStack(spacing: 10) {
                Capsule().fill(o.criticidad.color).frame(width: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(o.nombre).font(.app(.subheadline, .semibold)).strikethrough(o.estado == .completada)
                    Text(almacen.activo(o.activoId)?.nombreCompleto ?? "").font(.app(.caption)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(o.franja ?? String(localized: "Sin hora")).font(.app(.caption)).foregroundStyle(.secondary)
                Avatar(tecnico: almacen.tecnico(o.tecnicoIds.first), tamano: 22)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Menu {
                ForEach([0, 1, 2, 7], id: \.self) { n in
                    Button(n == 0 ? "Hoy" : n == 1 ? "Mañana" : n == 2 ? "Pasado mañana" : "Dentro de una semana") {
                        var x = o; x.proximo = Fechas.mas(Fechas.hoy, dias: n)
                        Task { await almacen.guardar(x) }
                    }
                }
            } label: { Label("Mover a…", systemImage: "calendar") }
            Menu {
                ForEach(almacen.tecnicos.filter(\.activo)) { w in
                    Button(w.nombreCompleto) { Task { await almacen.asignar(o, a: [w.id]) } }
                }
            } label: { Label("Asignar a…", systemImage: "person.badge.plus") }
        }
    }
}

/// Resumen de la OT al tocarla en el calendario: hora, duración, técnico y «Editar».
struct ResumenOT: View {
    @Environment(Almacen.self) private var almacen
    let ot: OrdenTrabajo
    @State private var editar = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(almacen.activo(ot.activoId)?.nombreCompleto ?? "").font(.app(.caption)).foregroundStyle(.secondary)
                        Text(ot.nombre).font(.app(.title3, .semibold))
                        HStack(spacing: 6) {
                            Insignia(texto: ot.criticidad.corta, color: ot.criticidad.color)
                            Insignia(texto: ot.estado.etiqueta, color: ot.estado.color)
                        }
                    }
                }
                Section {
                    if let p = almacen.plan(ot.planId) { LabeledContent("Mantenimiento", value: "\(p.nombre), \(p.cadaCuanto)") }
                    if let f = ot.proximo { LabeledContent("Día", value: Fechas.corta(f)) }
                    LabeledContent("Hora", value: ot.franja ?? String(localized: "Sin hora"))
                    HStack {
                        Text("Técnico")
                        Spacer()
                        Menu {
                            ForEach(almacen.tecnicos.filter(\.activo)) { w in
                                Button(w.nombreCompleto) { Task { await almacen.asignar(ot, a: [w.id]) } }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Avatar(tecnico: almacen.tecnico(almacen.orden(ot.id)?.tecnicoIds.first), tamano: 22)
                                Text(almacen.tecnico(almacen.orden(ot.id)?.tecnicoIds.first)?.nombre ?? String(localized: "Sin asignar"))
                            }
                        }
                    }
                }
                Section {
                    NavigationLink { OTDetalleView(otId: ot.id) } label: { Label("Editar", systemImage: "pencil") }
                }
            }
            .fondoTema()
            .hojaConsulta(String(localized: "Orden de trabajo"))
        }
    }
}
