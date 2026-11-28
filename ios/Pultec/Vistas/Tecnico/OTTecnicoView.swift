import SwiftUI
import PhotosUI

/// OT del técnico: Empezar → En curso (cronómetro, apuntes, fotos, checklist) → Pausar /
/// Crear incidencia / Cerrar OT. Si avisó una incidencia, queda pausada esperando a la oficina.
struct OTTecnicoView: View {
    @Environment(Almacen.self) private var almacen
    let otId: String
    @State private var cerrar = false
    @State private var incidencia = false
    @State private var informes: [Informe] = []
    @State private var parte: Informe?
    @AppStorage private var apuntes: String

    init(otId: String) {
        self.otId = otId
        _apuntes = AppStorage(wrappedValue: "", "apuntes-\(otId)")
    }

    var body: some View {
        if let ot = almacen.orden(otId) {
            contenido(ot)
        } else {
            EstadoVacio(icono: "list.clipboard", titulo: "Esta orden ya no existe").fondoTema()
        }
    }

    private func contenido(_ ot: OrdenTrabajo) -> some View {
        let espera = almacen.esperando(ot)
        let enCurso = ot.estado == .enCurso
        return List {
            Section {} header: { cabecera(ot) }
            if let espera {
                Section {} header: {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("OT pausada", systemImage: "pause.circle").font(.app(.headline)).foregroundStyle(Color.primary)
                        Text("Esperando la respuesta de la oficina a tu incidencia. Cuando responda, podrás reanudarla.").font(.app(.subheadline))
                        Text("«\(espera.descripcion)»").font(.app(.subheadline)).italic().foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.pAmbar.opacity(0.1), in: .rect(cornerRadius: 14, style: .continuous))
                    .textCase(nil)
                }
            }
            if enCurso && espera == nil {
                Section {
                    TextField("Apunta lo que vas viendo y haciendo: qué has cambiado, qué queda pendiente…", text: $apuntes, axis: .vertical)
                        .lineLimit(4...10)
                } header: { Text("Tus apuntes") } footer: {
                    Text("Se guardan solos en este dispositivo. Al cerrar la OT pasan a «Qué has hecho» del parte, donde puedes cambiarlos.")
                }
            }
            if !ot.checklist.isEmpty || !(almacen.plan(ot.planId)?.checklist.isEmpty ?? true) {
                ChecklistTecnico(ot: ot, editable: enCurso && espera == nil)
            }
            Section("Información") {
                LabeledContent("Activo", value: almacen.activo(ot.activoId)?.nombreCompleto ?? "—")
                if let f = ot.proximo {
                    LabeledContent("Cuándo", value: [Fechas.frase(Fechas.relativo(f)), ot.franja].compactMap { $0 }.joined(separator: ", "))
                }
                if !ot.descripcion.isEmpty { LabeledContent("Descripción") { Text(ot.descripcion).multilineTextAlignment(.trailing) } }
                if !ot.procedimiento.isEmpty { LabeledContent("Procedimiento") { Text(ot.procedimiento).multilineTextAlignment(.trailing) } }
                if !ot.repuestos.isEmpty { LabeledContent("Repuestos", value: ot.repuestos) }
            }
            if let i = almacen.incidenciaDe(ot: ot.id) {
                Section("Incidencia original") {
                    LabeledContent("Qué pasa") { Text(i.descripcion).multilineTextAlignment(.trailing) }
                    if let o = almacen.orden(i.origenTrabajoId) {
                        LabeledContent("Viene de", value: "«\(o.nombre)», \(String(localized: o.estado == .interrumpida ? "interrumpida" : "abierta"))")
                    }
                    LabeledContent("Comunicada", value: "\(almacen.tecnico(i.tecnicoId)?.nombre ?? "—"), \(Fechas.corta(i.creada))")
                    if !i.fotos.isEmpty { GaleriaFotos(rutas: i.fotos) }
                }
            }
            Section("Informes") {
                if informes.isEmpty {
                    Text("Aún no has enviado ningún informe de esta orden de trabajo.").font(.app(.subheadline)).foregroundStyle(.secondary)
                }
                ForEach(informes) { inf in
                    Button { parte = inf } label: {
                        HStack {
                            Punto(color: inf.resultado.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(inf.resultado.etiqueta).font(.app(.subheadline, .semibold))
                                if !inf.notas.isEmpty { Text(inf.notas).font(.app(.caption)).foregroundStyle(.secondary).lineLimit(2) }
                            }
                            Spacer()
                            Text(inf.cuando.formatted(date: .numeric, time: .shortened)).font(.app(.caption)).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .fondoTema()
        .navigationTitle(ot.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { botonera(ot, espera: espera != nil) }
        .task(id: ot.estado) { informes = await almacen.informes(de: ot.id) }
        .sheet(isPresented: $cerrar) { CerrarOTView(ot: ot, apuntes: apuntes) { apuntes = "" } }
        .sheet(isPresented: $incidencia) {
            CrearIncidenciaView(incidencia: .nueva(activo: ot.activoId ?? "", tecnico: almacen.tecnicoActivo, origen: ot.id))
        }
        .sheet(item: $parte) { InformeDetalleView(ot: ot, informe: $0) }
    }

    private func cabecera(_ ot: OrdenTrabajo) -> some View {
        HStack(spacing: 12) {
            IconoActivo(clave: almacen.activo(ot.activoId)?.icono ?? "brazo", tamano: 44)
            VStack(alignment: .leading, spacing: 6) {
                Text(ot.nombre).font(.system(size: 22, weight: .bold)).foregroundStyle(Color.primary)
                HStack(spacing: 6) {
                    Insignia(texto: ot.pausada ? "Pausada" : ot.estado == .completada ? "Hecho" : ot.estado.etiqueta,
                             color: ot.estado == .completada ? .pVerde : ot.estado == .enCurso ? .pAzul : .secondary)
                    Insignia(texto: ot.criticidad.corta, color: ot.criticidad.color)
                }
            }
        }
        .textCase(nil)
    }

    @ViewBuilder
    private func botonera(_ ot: OrdenTrabajo, espera: Bool) -> some View {
        if ot.estado.abierta {
            GlassEffectContainer {
                HStack(spacing: 10) {
                    Button { incidencia = true } label: { Image(systemName: "exclamationmark.circle").frame(height: 30) }
                        .buttonStyle(.glass).tint(.pRojo).accessibilityLabel(Text("Crear incidencia"))
                        .disabled(espera)
                    switch ot.estado {
                    case .pendiente:
                        Button { Task { await almacen.empezar(ot) } } label: {
                            Label("Empezar OT", systemImage: "play.fill").font(.app(.body, .semibold)).frame(maxWidth: .infinity, minHeight: 30)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(espera)
                    default:
                        Button { Task { await almacen.pausar(ot, !ot.pausada) } } label: {
                            Image(systemName: ot.pausada ? "play.fill" : "pause.fill").frame(height: 30)
                        }
                        .buttonStyle(.glass)
                        .disabled(espera)
                        .accessibilityLabel(Text(ot.pausada ? "Reanudar" : "Pausar"))
                        Cronometro(ot: ot)
                        Button { cerrar = true } label: {
                            Label("Cerrar OT", systemImage: "checkmark").font(.app(.body, .semibold)).frame(maxWidth: .infinity, minHeight: 30)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(espera)
                    }
                }
            }
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}

/// Tiempo trabajado desde «Empezar OT», sin las pausas.
struct Cronometro: View {
    @Environment(Almacen.self) private var almacen
    let ot: OrdenTrabajo

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let s = segundos
            Text(String(format: "%02d:%02d", s / 3600, (s / 60) % 60))
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundStyle(ot.pausada ? Color.secondary : Color.pAzul)
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .glassEffect()
        }
        .accessibilityLabel(Text("Tiempo trabajado"))
    }

    private var segundos: Int {
        guard let inicio = ot.iniciadaEn else { return 0 }
        let fin = ot.pausadaDesde ?? Date()
        return max(0, Int(fin.timeIntervalSince(inicio)) - ot.segundosPausa)
    }
}

/// Checklist de la OT: el técnico marca cada paso (se guarda al momento, `marcar_checklist`).
struct ChecklistTecnico: View {
    @Environment(Almacen.self) private var almacen
    let ot: OrdenTrabajo
    let editable: Bool

    private var pasos: [PasoChecklist] {
        ot.checklist.isEmpty ? (almacen.plan(ot.planId)?.checklist ?? []).map { PasoChecklist(paso: $0) } : ot.checklist
    }

    var body: some View {
        let l = pasos
        Section {
            ForEach(Array(l.enumerated()), id: \.offset) { n, p in
                Button {
                    guard editable else { return }
                    var nuevos = l
                    nuevos[n].hecho.toggle()
                    nuevos[n].cuando = nuevos[n].hecho ? Date() : nil
                    nuevos[n].por = nuevos[n].hecho ? almacen.tecnico(almacen.tecnicoActivo)?.nombreCompleto : nil
                    Task { await almacen.marcarChecklist(ot, nuevos) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: p.hecho ? "checkmark.circle.fill" : "circle")
                            .font(.title3).foregroundStyle(p.hecho ? Color.pVerde : .secondary)
                        Text(p.paso).strikethrough(p.hecho).foregroundStyle(p.hecho ? .secondary : Color.primary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: p.hecho)
            }
        } header: {
            Text("Checklist \(l.filter(\.hecho).count) de \(l.count)")
        }
    }
}
