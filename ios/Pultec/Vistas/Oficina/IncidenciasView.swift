import SwiftUI

/// Incidencias: Pendientes / Histórico, Todas · Abierta · Con OT, buscador; tocar → revisar.
struct IncidenciasView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(AppEstado.self) private var estado
    @State private var historico = false
    @State private var filtro: EstadoIncidencia?
    @State private var buscar = ""
    @State private var abierta: Incidencia?
    @State private var nueva = false

    private var lista: [Incidencia] {
        var r = almacen.incidencias.filter { historico ? !$0.estado.pendiente : $0.estado.pendiente }
        if let filtro { r = r.filter { $0.estado == filtro } }
        if !buscar.isEmpty {
            r = r.filter { $0.descripcion.localizedCaseInsensitiveContains(buscar) || (almacen.activo($0.activoId)?.nombreCompleto.localizedCaseInsensitiveContains(buscar) ?? false) }
        }
        return r
    }

    var body: some View {
        Pila {
            ListaRelieve {
                Section {} header: {
                    VStack(spacing: 10) {
                        Picker("Vista", selection: $historico) {
                            Text("Pendientes \(almacen.incidencias.filter(\.estado.pendiente).count)").tag(false)
                            Text("Histórico \(almacen.incidencias.filter { !$0.estado.pendiente }.count)").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: historico) { filtro = nil }
                        Picker("Estado", selection: $filtro) {
                            Text("Todas").tag(EstadoIncidencia?.none)
                            if historico {
                                Text("Completadas").tag(EstadoIncidencia?.some(.completada))
                                Text("Desestimadas").tag(EstadoIncidencia?.some(.desestimada))
                            } else {
                                Text("Abierta").tag(EstadoIncidencia?.some(.abierta))
                                Text("Con OT").tag(EstadoIncidencia?.some(.conOt))
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .textCase(nil)
                }
                Section {
                    ForEach(lista) { i in
                        Button { abierta = i } label: { FilaIncidencia(incidencia: i) }.buttonStyle(.plain)
                    }
                }
                if lista.isEmpty {
                    Section {} header: {
                        EstadoVacio(icono: "exclamationmark.circle", titulo: historico ? "Sin incidencias cerradas" : "Sin incidencias pendientes",
                                    mensaje: "Lo que comuniquen los técnicos aparece aquí para revisarlo.").textCase(nil)
                    }
                }
            }
            .searchable(text: $buscar, prompt: "Buscar incidencia…")
            .refreshable { await almacen.recargar() }
            .fondoTema()
            .tituloPantalla("Incidencias", icono: "exclamationmark.circle")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { nueva = true } label: { Image(systemName: "plus") }
                        .tint(.pRojo).accessibilityLabel(Text("Incidencia"))
                    BotonAvisos()
                }
            }
            .sheet(item: $abierta) { IncidenciaView(incidencia: $0) }
            .sheet(isPresented: $nueva) { IncidenciaView(incidencia: .nueva(), nueva: true) }
            .onAppear(perform: abrirPedida)
            .onChange(of: estado.abrirIncidencia) { abrirPedida() }
        }
    }

    private func abrirPedida() {
        if let id = estado.abrirIncidencia {
            estado.abrirIncidencia = nil
            abierta = almacen.incidencia(id)
        }
    }
}

/// Revisar una incidencia (oficina): qué pasa, de qué OT viene y qué hacer con ella.
/// Desde una OT abierta: Seguir en la misma OT · Interrumpir y crear OT · Desestimar.
/// Suelta: Crear OT · Desestimar. Con OT: Cancelar OT y desestimar. Desestimada: Reabrir.
struct IncidenciaView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var dismiss
    let original: Incidencia
    let nueva: Bool
    @State private var i: Incidencia
    @State private var elegirActivo = false
    @State private var confirmarInterrumpir = false
    @State private var confirmarCancelar = false
    @State private var otCreada: OrdenTrabajo?

    init(incidencia: Incidencia, nueva: Bool = false) {
        original = incidencia
        self.nueva = nueva
        _i = State(initialValue: incidencia)
    }

    private var origen: OrdenTrabajo? { almacen.orden(i.origenTrabajoId).flatMap { $0.estado.abierta ? $0 : nil } }
    private var puede: Bool { !i.activoId.isEmpty && !i.descripcion.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ListaRelieve {
                if !nueva {
                    Section {} header: {
                        HStack(spacing: 8) {
                            Avatar(tecnico: almacen.tecnico(i.tecnicoId), tamano: 22)
                            Text("Comunicada por \(almacen.tecnico(i.tecnicoId)?.nombre ?? String(localized: "la oficina")) el \(i.creada.formatted(date: .numeric, time: .shortened))")
                                .font(.app(.caption))
                            Spacer()
                            Insignia(texto: i.estado.etiqueta, color: i.estado.color, icono: i.estado.icono)
                        }
                        .textCase(nil)
                    }
                }
                Section("Incidencia") {
                    Button { elegirActivo = true } label: {
                        HStack {
                            Text("Activo o componente").foregroundStyle(Color.primary)
                            Spacer()
                            Text(almacen.activo(i.activoId)?.nombreCompleto ?? String(localized: "Elegir activo"))
                                .foregroundStyle(i.activoId.isEmpty ? Color.pMorado : .secondary).lineLimit(1)
                        }
                    }
                    .disabled(!i.estado.pendiente)
                    TextField("Qué pasa (pierde aceite por la junta)", text: $i.descripcion, axis: .vertical).lineLimit(2...6)
                    Picker("Gravedad", selection: $i.gravedad) {
                        Text("Correctivo no crítico").tag(Gravedad.media)
                        Text("Correctivo crítico").tag(Gravedad.grave)
                    }
                    Picker("Mantenimiento vinculado", selection: $i.planId) {
                        Text("Sin vincular").tag(String?.none)
                        ForEach(almacen.planesDe(i.activoId)) { Text($0.nombre).tag(String?.some($0.id)) }
                    }
                }
                if !i.fotos.isEmpty {
                    Section("Fotos") { GaleriaFotos(rutas: i.fotos) }
                }
                if let o = almacen.orden(i.origenTrabajoId) {
                    Section("Orden en la que se detectó") {
                        NavigationLink { OTDetalleView(otId: o.id) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(o.nombre).font(.app(.body, .medium))
                                Text(o.estado.etiqueta).font(.app(.caption)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if let ot = almacen.orden(i.trabajoId), ot.id != i.origenTrabajoId {
                    Section("Su orden de trabajo") {
                        NavigationLink { OTDetalleView(otId: ot.id) } label: { FilaOT(ot: ot) }
                    }
                }
                if !nueva { acciones }
            }
            .fondoTema()
            .navigationTitle(nueva ? String(localized: "Nueva incidencia") : String(localized: "Incidencia"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { BotonCerrar() }
                if nueva || (i.estado.pendiente && i != original) {
                    ToolbarItem(placement: .topBarTrailing) {
                        BotonConfirmar(activo: puede) { Task { await almacen.guardar(i); dismiss() } }
                    }
                }
            }
            .sheet(isPresented: $elegirActivo) { SelectorActivo(seleccion: Binding(get: { i.activoId }, set: { i.activoId = $0 ?? "" })) }
            .sheet(item: $otCreada, onDismiss: { dismiss() }) { o in NavigationStack { OTEditor(original: o, nueva: false).toolbar { ToolbarItem(placement: .topBarLeading) { BotonCerrar() } } } }
            .confirmationDialog("¿Interrumpir «\(origen?.nombre ?? "")» y crear una OT correctiva?", isPresented: $confirmarInterrumpir, titleVisibility: .visible) {
                Button("Interrumpir y crear OT", role: .destructive) {
                    Task { otCreada = await almacen.crearOT(para: i, interrumpiendo: origen) }
                }
            } message: { Text("La orden queda cerrada como interrumpida y el trabajo sigue en la nueva.") }
            .confirmationDialog("¿Cancelar su orden de trabajo y desestimar la incidencia?", isPresented: $confirmarCancelar, titleVisibility: .visible) {
                Button("Cancelar OT y desestimar", role: .destructive) { Task { await almacen.cancelarOTyDesestimar(i); dismiss() } }
            } message: { Text("La orden queda en el histórico como cancelada.") }
        }
    }

    @ViewBuilder
    private var acciones: some View {
        Section {
            switch i.estado {
            case .abierta:
                if let o = origen {
                    if i.gravedad == .grave {
                        accion("Interrumpir y crear OT", "arrow.triangle.branch", principal: true) { confirmarInterrumpir = true }
                        accion("Seguir en la misma OT", "arrow.uturn.forward") { Task { await almacen.seguirEnLaOT(i); dismiss() } }
                    } else {
                        accion("Seguir en la misma OT", "arrow.uturn.forward", principal: true) { Task { await almacen.seguirEnLaOT(i); dismiss() } }
                        accion("Interrumpir y crear OT", "arrow.triangle.branch") { confirmarInterrumpir = true }
                    }
                    let _ = o
                } else {
                    accion("Crear OT", "list.clipboard", principal: true) { Task { otCreada = await almacen.crearOT(para: i) } }
                }
                accion("Desestimar", "xmark.circle") { Task { await almacen.desestimar(i); dismiss() } }
            case .conOt:
                Button(role: .destructive) { confirmarCancelar = true } label: { Label("Cancelar OT y desestimar", systemImage: "xmark.circle") }
            case .desestimada:
                accion("Reabrir", "arrow.counterclockwise") { Task { await almacen.reabrir(i); dismiss() } }
            case .completada:
                Label("Resuelta \(i.cerradaEl.map(Fechas.corta) ?? "")", systemImage: "checkmark.circle.fill").foregroundStyle(Color.pVerde)
            }
        } header: {
            Text("Acciones")
        } footer: {
            if i.estado == .abierta, origen != nil {
                Text("Avisada desde una orden abierta: el técnico espera tu respuesta para seguir.")
            }
        }
    }

    private func accion(_ titulo: LocalizedStringKey, _ icono: String, principal: Bool = false, _ hacer: @escaping () -> Void) -> some View {
        Button(action: hacer) {
            Label(titulo, systemImage: icono).font(.app(.body, principal ? .semibold : .regular))
                .foregroundStyle(principal ? Color.pMorado : Color.primary)
        }
    }
}

/// Fotos guardadas en el bucket, en tira horizontal; tocar = pantalla completa.
struct GaleriaFotos: View {
    @Environment(Almacen.self) private var almacen
    let rutas: [String]
    @State private var imagenes: [String: UIImage] = [:]
    @State private var grande: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(rutas, id: \.self) { r in
                    Group {
                        if let img = imagenes[r] { Image(uiImage: img).resizable().scaledToFill() }
                        else { Color.gray.opacity(0.15).overlay(ProgressView()) }
                    }
                    .frame(width: 120, height: 90)
                    .clipShape(.rect(cornerRadius: 12, style: .continuous))
                    .onTapGesture { grande = r }
                    .task { if imagenes[r] == nil, let d = await almacen.foto(r) { imagenes[r] = UIImage(data: d) } }
                }
            }
        }
        .fullScreenCover(item: Binding(get: { grande.map { RutaFoto(id: $0) } }, set: { grande = $0?.id })) { f in
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()
                if let img = imagenes[f.id] { Image(uiImage: img).resizable().scaledToFit() }
                Button { grande = nil } label: { Image(systemName: "xmark").font(.title3.bold()).padding() }
                    .buttonStyle(.glass).padding()
                    .accessibilityLabel(Text("Cerrar"))
            }
        }
    }

    private struct RutaFoto: Identifiable { let id: String }
}
