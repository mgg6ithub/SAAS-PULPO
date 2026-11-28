import SwiftUI

/// «Crear incidencia» del técnico: dónde, qué ocurre (gravedad) y fotos. «Enviar» apagado hasta tener
/// activo y descripción. Desde una OT abierta, esa OT queda pausada esperando a la oficina.
struct CrearIncidenciaView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var dismiss
    @State private var i: Incidencia
    @State private var fotos: [Data] = []
    @State private var elegirActivo = false
    @State private var enviando = false
    let editar: Bool

    init(incidencia: Incidencia, editar: Bool = false) {
        _i = State(initialValue: incidencia)
        self.editar = editar
    }

    private var falta: LocalizedStringKey? {
        if i.activoId.isEmpty { return "Te falta el activo o componente" }
        if i.descripcion.trimmingCharacters(in: .whitespaces).isEmpty { return "Te falta la descripción" }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SelectorFotos(fotos: $fotos)
                    if !i.fotos.isEmpty { GaleriaFotos(rutas: i.fotos) }
                } header: { Text("Fotos") } footer: { Text("Hasta 6 fotos de la avería.") }
                Section("Dónde") {
                    Button { elegirActivo = true } label: {
                        HStack {
                            Text("Activo o componente").foregroundStyle(Color.primary)
                            Spacer()
                            Text(almacen.activo(i.activoId)?.nombreCompleto ?? String(localized: "Elegir activo"))
                                .foregroundStyle(i.activoId.isEmpty ? Color.pMorado : .secondary).lineLimit(1)
                        }
                    }
                    Picker("Orden relacionada", selection: $i.origenTrabajoId) {
                        Text("Sin orden asociada").tag(String?.none)
                        ForEach(almacen.misOrdenes(almacen.tecnicoActivo ?? "").filter { almacen.arbol(almacen.raiz(i.activoId)?.id ?? "").contains($0.activoId ?? "") }) {
                            Text($0.nombre).tag(String?.some($0.id))
                        }
                        if let o = i.origenTrabajoId, let ot = almacen.orden(o) { Text(ot.nombre).tag(String?.some(o)) }
                    }
                }
                Section("Qué ocurre") {
                    TextField("Pierde aceite por la junta de la bomba", text: $i.descripcion, axis: .vertical).lineLimit(3...8)
                    Picker("Gravedad", selection: $i.gravedad) {
                        Text("Correctivo no crítico").tag(Gravedad.media)
                        Text("Correctivo crítico").tag(Gravedad.grave)
                    }
                }
                if let falta { Section {} footer: { AvisoFalta(texto: falta) } }
            }
            .fondoTema()
            .disabled(enviando)
            .navigationTitle(editar ? String(localized: "Editar incidencia") : String(localized: "Crear incidencia"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { BotonCerrar() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) { enviar() } label: { Image(systemName: "paperplane.fill") }
                        .tint(.pRojo)
                        .disabled(falta != nil || enviando)
                        .accessibilityLabel(Text(editar ? "Enviar cambios" : "Enviar"))
                }
            }
            .sheet(isPresented: $elegirActivo) { SelectorActivo(seleccion: Binding(get: { i.activoId }, set: { i.activoId = $0 ?? "" })) }
        }
    }

    private func enviar() {
        enviando = true
        Task {
            if editar {
                await almacen.editarIncidencia(i)
                dismiss()
            } else if await almacen.crearIncidencia(i, fotos: fotos) {
                dismiss()
            }
            enviando = false
        }
    }
}

/// Incidencias que ha enviado el técnico; editables mientras estén abiertas.
struct MisIncidenciasView: View {
    @Environment(Almacen.self) private var almacen
    @State private var editar: Incidencia?
    @State private var ver: Incidencia?
    @State private var nueva = false

    var body: some View {
        let yo = almacen.tecnicoActivo ?? ""
        let mias = almacen.incidencias.filter { $0.tecnicoId == yo }
        NavigationStack {
            List {
                Section {} header: {
                    Consejo("¿Se te ha olvidado algo? Toca una incidencia abierta para cambiarla. Cuando le asignen una OT ya no se podrá editar.", clave: "tec-incidencias")
                }
                Section {
                    ForEach(mias) { i in
                        Button { if i.estado == .abierta { editar = i } else { ver = i } } label: { FilaIncidencia(incidencia: i) }
                            .buttonStyle(.plain)
                    }
                }
                if mias.isEmpty {
                    Section {} header: {
                        EstadoVacio(icono: "line.3.horizontal.decrease", titulo: "No tienes incidencias enviadas", mensaje: "Lo que comuniques aparece aquí.").textCase(nil)
                    }
                }
            }
            .refreshable { await almacen.recargar() }
            .fondoTema()
            .navigationTitle("Incidencias")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { MenuPerfilTecnico() }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { nueva = true } label: { Image(systemName: "exclamationmark.circle.fill") }
                        .tint(.pRojo).accessibilityLabel(Text("Crear incidencia"))
                    BotonAvisos()
                }
            }
            .sheet(item: $editar) { CrearIncidenciaView(incidencia: $0, editar: true) }
            .sheet(item: $ver) { i in
                NavigationStack {
                    List {
                        Section { FilaIncidencia(incidencia: i) }
                        if !i.fotos.isEmpty { Section("Fotos") { GaleriaFotos(rutas: i.fotos) } }
                        if let ot = almacen.orden(i.trabajoId) { Section("Su orden de trabajo") { FilaOT(ot: ot) } }
                    }
                    .fondoTema()
                    .hojaConsulta(String(localized: "Incidencia"))
                }
            }
            .sheet(isPresented: $nueva) { CrearIncidenciaView(incidencia: .nueva(tecnico: yo)) }
        }
    }
}

/// Histórico del técnico: partes enviados, agrupados por día; tocar → parte.
struct HistoricoTecnicoView: View {
    @Environment(Almacen.self) private var almacen
    @State private var informes: [Informe] = []
    @State private var cargado = false
    @State private var buscar = ""
    @State private var resultado: Resultado?
    @State private var abierto: Informe?

    var body: some View {
        let yo = almacen.tecnicoActivo ?? ""
        let lista = informes.filter { inf in
            (resultado == nil || inf.resultado == resultado)
                && (buscar.isEmpty || (almacen.orden(inf.trabajoId)?.nombre.localizedCaseInsensitiveContains(buscar) ?? false) || inf.notas.localizedCaseInsensitiveContains(buscar))
        }
        let dias = Dictionary(grouping: lista) { Calendar.current.startOfDay(for: $0.cuando) }.sorted { $0.key > $1.key }
        NavigationStack {
            List {
                ForEach(dias, id: \.key) { dia, l in
                    Section(Fechas.frase(Fechas.larga(dia))) {
                        ForEach(l) { inf in
                            Button { abierto = inf } label: { fila(inf) }.buttonStyle(.plain)
                        }
                    }
                }
                if cargado && lista.isEmpty {
                    Section {} header: {
                        EstadoVacio(icono: "line.3.horizontal.decrease", titulo: "No tienes partes registrados con estos filtros",
                                    mensaje: "Prueba a cambiar los filtros o la búsqueda.").textCase(nil)
                    }
                }
            }
            .searchable(text: $buscar, prompt: "Buscar…")
            .refreshable { informes = await almacen.informes(deTecnico: yo) }
            .fondoTema()
            .navigationTitle("Histórico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { MenuPerfilTecnico() }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Resultado del parte", selection: $resultado) {
                            Text("Todos").tag(Resultado?.none)
                            ForEach(Resultado.allCases) { Text($0.etiqueta).tag(Resultado?.some($0)) }
                        }
                    } label: { Image(systemName: resultado == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill") }
                    .accessibilityLabel(Text("Filtros"))
                }
            }
            .task(id: yo) { informes = await almacen.informes(deTecnico: yo); cargado = true }
            .sheet(item: $abierto) { inf in InformeDetalleView(ot: almacen.orden(inf.trabajoId), informe: inf) }
        }
    }

    private func fila(_ inf: Informe) -> some View {
        let ot = almacen.orden(inf.trabajoId)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: inf.resultado == .correcto ? "checkmark.circle.fill" : "exclamationmark.circle.fill").foregroundStyle(inf.resultado.color)
            VStack(alignment: .leading, spacing: 3) {
                Text(ot?.nombre ?? String(localized: "Orden de trabajo")).font(.app(.body, .semibold))
                if !inf.notas.isEmpty { Text(inf.notas).font(.app(.caption)).foregroundStyle(.secondary).lineLimit(2) }
                HStack(spacing: 6) {
                    Insignia(texto: inf.resultado.etiqueta, color: inf.resultado.color)
                    if let o = ot { Insignia(texto: o.criticidad.corta, color: o.criticidad.color) }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(inf.cuando.formatted(date: .omitted, time: .shortened)).font(.app(.caption)).foregroundStyle(.secondary)
                if let m = inf.minutos { Text("\(m) min").font(.app(.caption2)).foregroundStyle(.tertiary) }
            }
        }
        .contentShape(.rect)
    }
}

/// Parte enviado (solo lectura): incidencia original, la orden, el activo, quién y cuándo, fotos y firma.
struct InformeDetalleView: View {
    @Environment(Almacen.self) private var almacen
    let ot: OrdenTrabajo?
    let informe: Informe

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ot?.nombre ?? "").font(.app(.title3, .semibold))
                        if let d = ot?.descripcion, !d.isEmpty { Text(d).font(.app(.subheadline)).foregroundStyle(.secondary) }
                        Insignia(texto: informe.resultado.etiqueta, color: informe.resultado.color)
                    }
                }
                if let o = ot, let i = almacen.incidenciaDe(ot: o.id) {
                    Section("Incidencia original") { Text(i.descripcion) }
                }
                Section("Orden de trabajo") {
                    if let o = ot {
                        LabeledContent("Número", value: "OT-\(o.id.prefix(8).uppercased())")
                        LabeledContent("Criticidad") { Insignia(texto: o.criticidad.etiqueta, color: o.criticidad.color) }
                        LabeledContent("Origen") { Text(almacen.origen(o).0) }
                        if let p = almacen.plan(o.planId) { LabeledContent("Mantenimiento", value: "\(p.nombre), \(p.cadaCuanto)") }
                    }
                    if let a = almacen.activo(ot?.activoId) { LabeledContent("Activo", value: a.nombreCompleto) }
                }
                Section("Trabajo") {
                    LabeledContent("Realizado el", value: informe.cuando.formatted(date: .numeric, time: .shortened))
                    LabeledContent("Técnico", value: almacen.tecnico(informe.trabajadorId)?.nombreCompleto ?? "—")
                    LabeledContent("Tiempo", value: informe.minutos.map { "\($0) min" } ?? "—")
                    if !informe.notas.isEmpty { LabeledContent("Qué se hizo") { Text(informe.notas).multilineTextAlignment(.trailing) } }
                    if !informe.material.isEmpty { LabeledContent("Repuestos", value: informe.material) }
                    if let v = informe.valor { LabeledContent("Medición", value: v.formatted()) }
                }
                if !informe.fotos.isEmpty { Section("Fotos") { GaleriaFotos(rutas: informe.fotos) } }
                if let f = informe.firma { Section("Firma") { GaleriaFotos(rutas: [f]) } }
            }
            .fondoTema()
            .hojaConsulta(String(localized: "Parte de orden de trabajo"))
        }
    }
}

/// «Ver parte» de la oficina: los partes de la OT.
struct ParteView: View {
    @Environment(Almacen.self) private var almacen
    let ot: OrdenTrabajo
    @State private var informes: [Informe] = []

    var body: some View {
        Group {
            if let ultimo = informes.first { InformeDetalleView(ot: ot, informe: ultimo) }
            else { NavigationStack { EstadoVacio(icono: "doc.text", titulo: "Sin parte").hojaConsulta(ot.nombre) } }
        }
        .task { informes = await almacen.informes(de: ot.id) }
    }
}

/// Mi perfil del técnico: teléfono y apariencia (la foto, en la web por ahora).
struct PerfilTecnicoView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var dismiss
    @State private var telefono = ""

    var body: some View {
        @Bindable var estado = estado
        let w = almacen.tecnico(almacen.tecnicoActivo)
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Avatar(tecnico: w, tamano: 56, conEstado: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w?.nombreCompleto ?? "").font(.app(.headline))
                            Text(w?.email ?? "").font(.app(.subheadline)).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Datos") {
                    TextField("Teléfono", text: $telefono).keyboardType(.phonePad)
                }
                Section("Apariencia") {
                    Picker("Tema", selection: $estado.tema) { ForEach(Tema.allCases) { Text($0.nombre).tag($0) } }
                }
                Section {
                    if almacen.viendoComo != nil {
                        Text("Estás viendo la app como \(w?.nombre ?? ""). Cuando entre con su propia cuenta, aquí podrá cambiar su correo y contraseña.")
                            .font(.app(.footnote)).foregroundStyle(.secondary)
                    }
                    Button("Cerrar sesión", role: .destructive) { Task { await almacen.salir() } }
                } header: { Text("Cuenta") }
            }
            .fondoTema()
            .hojaFormulario(String(localized: "Mi perfil"), puedeGuardar: telefono != (w?.telefono ?? "")) {
                Task {
                    if almacen.viendoComo == nil {
                        await almacen.guardarMiPerfil(telefono: telefono)
                    } else if var t = w {
                        t.telefono = telefono
                        await almacen.guardar(t)
                    }
                    dismiss()
                }
            }
            .onAppear { telefono = w?.telefono ?? "" }
        }
    }
}
