import SwiftUI

/// Ficha de la OT (oficina): cadena Activo → Mantenimiento/Incidencia → Orden y el
/// formulario editable directo. Completada: «Ver parte».
struct OTDetalleView: View {
    @Environment(Almacen.self) private var almacen
    let otId: String

    var body: some View {
        if let ot = almacen.orden(otId) {
            OTEditor(original: ot, nueva: false).id(ot.id)
        } else {
            EstadoVacio(icono: "list.clipboard", titulo: "Esta orden ya no existe").fondoTema()
        }
    }
}

/// Formulario de la OT: nueva (hoja con X y ✓) o ficha (✓ cuando hay cambios).
struct OTEditor: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var dismiss
    let original: OrdenTrabajo
    let nueva: Bool

    @State private var ot: OrdenTrabajo
    @State private var tecnicos: [String]
    @State private var conHora: Bool
    @State private var elegirActivo = false
    @State private var verParte = false
    @State private var confirmarBorrar = false
    @State private var nuevoPaso = ""

    init(original: OrdenTrabajo, nueva: Bool) {
        self.original = original
        self.nueva = nueva
        _ot = State(initialValue: original)
        _tecnicos = State(initialValue: original.tecnicoIds)
        _conHora = State(initialValue: original.inicioMin != nil)
    }

    private var puedeGuardar: Bool { !ot.nombre.trimmingCharacters(in: .whitespaces).isEmpty && ot.activoId != nil && ot.proximo != nil }
    private var cambiado: Bool { ot != original || tecnicos != original.tecnicoIds }
    private var falta: LocalizedStringKey? {
        if ot.nombre.trimmingCharacters(in: .whitespaces).isEmpty { return "Te falta el nombre" }
        if ot.activoId == nil { return "Te falta el activo" }
        return nil
    }

    var body: some View {
        ListaRelieve {
            if !nueva { Section {} header: { cadena } }
            Section {
                TextField("Revisión del motor, cambio de filtro…", text: $ot.nombre)
                TextField("Qué hay que hacer en esta orden", text: $ot.descripcion, axis: .vertical).lineLimit(2...5)
                Picker("Criticidad", selection: $ot.criticidad) {
                    ForEach(Criticidad.allCases) { Text($0.etiqueta).tag($0) }
                }
            } header: { Text("Qué hay que hacer") }

            Section("Activo y técnico") {
                Button { elegirActivo = true } label: {
                    HStack {
                        Text("Activo o componente").foregroundStyle(Color.primary)
                        Spacer()
                        Text(almacen.activo(ot.activoId)?.nombreCompleto ?? String(localized: "Elegir activo"))
                            .foregroundStyle(ot.activoId == nil ? Color.pMorado : .secondary).lineLimit(1)
                        Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                    }
                }
                Picker("Técnico", selection: Binding(get: { tecnicos.first }, set: { tecnicos = $0.map { [$0] } ?? [] })) {
                    Text("Sin asignar").tag(String?.none)
                    ForEach(almacen.tecnicos.filter(\.activo)) { Text($0.nombreCompleto).tag(String?.some($0.id)) }
                }
                Button {
                    if let w = almacen.masAdecuado(grupo: ot.grupoId) { tecnicos = [w.id] }
                } label: { Label("El más adecuado", systemImage: "sparkles") }
            }

            Section("Cuándo") {
                DatePicker("Día", selection: Binding(get: { ot.proximo ?? Fechas.hoy }, set: { ot.proximo = Calendar.current.startOfDay(for: $0) }),
                           displayedComponents: .date)
                Toggle("Hora fija", isOn: $conHora.animation())
                    .onChange(of: conHora) { _, v in ot.inicioMin = v ? (ot.inicioMin ?? 480) : nil }
                if conHora {
                    DatePicker("Hora", selection: Binding(
                        get: { Calendar.current.date(bySettingHour: (ot.inicioMin ?? 480) / 60, minute: (ot.inicioMin ?? 480) % 60, second: 0, of: Date()) ?? Date() },
                        set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); ot.inicioMin = (c.hour ?? 8) * 60 + (c.minute ?? 0) }),
                               displayedComponents: .hourAndMinute)
                }
                Picker("Duración prevista", selection: Binding(get: { ot.duracionMin ?? 60 }, set: { ot.duracionMin = $0 })) {
                    ForEach([15, 30, 45, 60, 90, 120, 180, 240, 480], id: \.self) { m in
                        Text(m < 60 ? "\(m) min" : m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60) min").tag(m)
                    }
                }
            }

            Section {
                ForEach($ot.checklist) { $p in
                    HStack {
                        Image(systemName: p.hecho ? "checkmark.circle.fill" : "circle").foregroundStyle(p.hecho ? Color.pVerde : .secondary)
                        TextField("Paso", text: $p.paso)
                    }
                }
                .onDelete { ot.checklist.remove(atOffsets: $0) }
                .onMove { ot.checklist.move(fromOffsets: $0, toOffset: $1) }
                HStack {
                    TextField("Añadir paso", text: $nuevoPaso).onSubmit(anadirPaso)
                    Button(action: anadirPaso) { Image(systemName: "plus.circle.fill") }.disabled(nuevoPaso.isEmpty)
                        .accessibilityLabel(Text("Añadir paso"))
                }
            } header: { Text("Checklist") } footer: { Text("Se guarda sola y el técnico la ve al momento.") }

            Section("Intervención") {
                TextField("Procedimiento: cómo se hace, paso a paso", text: $ot.procedimiento, axis: .vertical).lineLimit(2...6)
                TextField("Repuestos: junta tórica 40 mm, aceite ISO 46…", text: $ot.repuestos, axis: .vertical).lineLimit(1...4)
                TextField("Notas / observaciones", text: $ot.notas, axis: .vertical).lineLimit(1...4)
                Toggle("Orden habilitada", isOn: $ot.activa)
            }

            if !nueva {
                Section {
                    if ot.estado.abierta {
                        Button(role: .destructive) { Task { await almacen.cambiarEstado(original, .cancelada); dismiss() } } label: {
                            Label("Cancelar la orden", systemImage: "xmark.circle")
                        }
                    }
                    Button(role: .destructive) { confirmarBorrar = true } label: { Label("Eliminar", systemImage: "trash") }
                        .foregroundStyle(.red)
                }
            }
            if let falta, nueva { Section {} footer: { AvisoFalta(texto: falta) } }
        }
        .fondoTema()
        .environment(\.editMode, .constant(.inactive))
        .modifier(BarraEditor(titulo: nueva ? String(localized: "Nueva orden de trabajo") : ot.nombre, nueva: nueva,
                              puedeGuardar: puedeGuardar && (nueva || cambiado), guardar: guardar))
        .toolbar {
            if !nueva, ot.estado == .completada {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { verParte = true } label: { Image(systemName: "doc.text.magnifyingglass") }
                        .accessibilityLabel(Text("Ver parte"))
                }
            }
        }
        .sheet(isPresented: $elegirActivo) { SelectorActivo(seleccion: $ot.activoId) }
        .sheet(isPresented: $verParte) { ParteView(ot: original) }
        .confirmationDialog("¿Eliminar «\(original.nombre)»?", isPresented: $confirmarBorrar, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { Task { await almacen.borrar(ot: original); dismiss() } }
        }
    }

    /// Activo → Mantenimiento o Incidencia → Orden → Solucionada.
    private var cadena: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if let a = almacen.activo(ot.activoId) {
                    NavigationLink { ActivoDetalleView(activoId: a.id) } label: { eslabon("Activo", a.nombreCompleto, icono: IconoActivo.simbolo(a.icono)) }
                    flecha
                }
                if let i = almacen.incidenciaDe(ot: ot.id) {
                    eslabon("Incidencia", i.descripcion, color: i.gravedad.color)
                    flecha
                } else if let p = almacen.plan(ot.planId) {
                    eslabon("Mantenimiento", p.nombre, color: .pVerde)
                    flecha
                }
                eslabon("Orden de trabajo", ot.nombre, color: .pMorado, actual: true)
                if ot.estado == .completada {
                    flecha
                    eslabon("Solucionada", [ot.completadaEl.map(Fechas.corta), ot.completadaPor].compactMap { $0 }.joined(separator: ", "),
                            color: .pVerde, icono: "checkmark.circle.fill")
                }
            }
            .padding(.vertical, 4)
        }
        .textCase(nil)
    }

    private var flecha: some View { Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary) }

    private func eslabon(_ titulo: LocalizedStringKey, _ valor: String, color: Color = .secondary, icono: String? = nil, actual: Bool = false) -> some View {
        HStack(spacing: 6) {
            if let icono { Image(systemName: icono).foregroundStyle(color) } else { Punto(color: color) }
            VStack(alignment: .leading, spacing: 1) {
                Text(titulo).font(.app(.caption2)).foregroundStyle(.secondary)
                Text(valor).font(.app(.caption, .semibold)).foregroundStyle(actual ? Color.pMorado : Color.primary).lineLimit(1)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(actual ? Color.pMorado.opacity(0.1) : Color.gray.opacity(0.1), in: .rect(cornerRadius: 10, style: .continuous))
    }

    private func anadirPaso() {
        let p = nuevoPaso.trimmingCharacters(in: .whitespaces)
        guard !p.isEmpty else { return }
        ot.checklist.append(PasoChecklist(paso: p))
        nuevoPaso = ""
    }

    private func guardar() {
        Task {
            await almacen.guardar(ot, tecnicos: tecnicos)
            if ot.checklist != original.checklist { await almacen.marcarChecklist(ot, ot.checklist) }
            if nueva { dismiss() }
        }
    }
}

/// Barra de los editores: nueva → X, título centrado, ✓; ficha → ✓ a la derecha si hay cambios.
struct BarraEditor: ViewModifier {
    let titulo: String
    let nueva: Bool
    let puedeGuardar: Bool
    let guardar: () -> Void

    func body(content: Content) -> some View {
        if nueva {
            content.hojaFormulario(titulo, puedeGuardar: puedeGuardar, guardar: guardar)
        } else {
            content
                .navigationTitle(titulo)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if puedeGuardar { BotonConfirmar(activo: true, accion: guardar) }
                    }
                }
        }
    }
}

/// Elegir activo o componente: buscador y árbol (tocar elige; la flecha baja a sus componentes).
struct SelectorActivo: View {
    @Binding var seleccion: String?

    var body: some View {
        NavigationStack {
            ListaSelectorActivo(padre: nil, seleccion: $seleccion)
                .hojaConsulta(String(localized: "Elegir activo"))
        }
    }
}

struct ListaSelectorActivo: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var dismiss
    let padre: String?
    @Binding var seleccion: String?
    @State private var buscar = ""

    var body: some View {
        let base = padre == nil ? (buscar.isEmpty ? almacen.raices : almacen.activos) : almacen.hijos(padre!)
        let filtrados = buscar.isEmpty ? base : base.filter { $0.nombreCompleto.localizedCaseInsensitiveContains(buscar) }
        List(filtrados) { a in
            HStack(spacing: 12) {
                Button {
                    seleccion = a.id
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        IconoActivo(clave: a.icono, tamano: 30)
                        Text(a.nombreCompleto).foregroundStyle(Color.primary)
                        Spacer()
                        if seleccion == a.id { Image(systemName: "checkmark").foregroundStyle(Color.pMorado) }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                if !almacen.hijos(a.id).isEmpty {
                    NavigationLink {
                        ListaSelectorActivo(padre: a.id, seleccion: $seleccion).navigationTitle(a.nombre)
                    } label: { EmptyView() }
                    .frame(width: 20)
                }
            }
        }
        .searchable(text: $buscar, prompt: "Buscar activo…")
        .fondoTema()
    }
}
