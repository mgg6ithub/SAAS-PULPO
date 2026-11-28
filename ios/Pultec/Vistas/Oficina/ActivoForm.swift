import SwiftUI

/// «Nuevo activo» / «Nuevo componente» (hoja con X y ✓): el formulario industrial de la web.
struct ActivoForm: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var dismiss
    let original: Activo
    let nuevo: Bool
    @State private var a: Activo

    init(original: Activo, nuevo: Bool) {
        self.original = original
        self.nuevo = nuevo
        _a = State(initialValue: original)
    }

    private var puede: Bool { !a.nombre.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        Form {
            CamposActivo(a: $a)
            if !puede { Section {} footer: { AvisoFalta(texto: "Te falta el nombre") } }
        }
        .fondoTema()
        .hojaFormulario(a.padreId == nil ? String(localized: "Nuevo activo") : String(localized: "Nuevo componente"), puedeGuardar: puede) {
            Task { await almacen.guardar(a); dismiss() }
        }
    }
}

/// Pestaña «Información» del activo: la ficha, que se guarda sola al cambiar.
struct ActivoCampos: View {
    @Environment(Almacen.self) private var almacen
    let original: Activo
    @State private var a: Activo
    @State private var guardado: Task<Void, Never>?

    init(original: Activo) {
        self.original = original
        _a = State(initialValue: original)
    }

    var body: some View {
        CamposActivo(a: $a)
            .onChange(of: a) { _, nuevo in
                guard !nuevo.nombre.isEmpty else { return }
                guardado?.cancel()
                guardado = Task {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    await almacen.guardar(nuevo)
                }
            }
    }
}

/// Campos del activo: Activo · Contador y uso · Ficha técnica · Repuestos · Notas · Checklist.
struct CamposActivo: View {
    @Binding var a: Activo
    @State private var nuevoPaso = ""
    private let rejilla = [GridItem(.adaptive(minimum: 44), spacing: 10)]

    var body: some View {
        Section {
            TextField("Tag (CAM-01)", text: $a.tag).textInputAutocapitalization(.characters)
            TextField("Nombre (Camión cisterna)", text: $a.nombre)
            TextField("Descripción (transporte de residuos líquidos)", text: $a.descripcion, axis: .vertical).lineLimit(1...4)
        } header: { Text("Activo") } footer: { Text("Qué máquina es y cómo se identifica.") }

        Section("Icono") {
            LazyVGrid(columns: rejilla, spacing: 10) {
                ForEach(IconoActivo.catalogo, id: \.0) { clave, nombre, simbolo in
                    Button { a.icono = clave } label: {
                        Image(systemName: simbolo)
                            .font(.system(size: 18))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(a.icono == clave ? Color.pMorado : .secondary)
                            .background(a.icono == clave ? Color.pMorado.opacity(0.14) : Color.gray.opacity(0.08),
                                        in: .rect(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(nombre))
                    .sensoryFeedback(.selection, trigger: a.icono)
                }
            }
            .padding(.vertical, 4)
        }

        if a.padreId == nil {
            Section {
                DatePicker("Fecha de la lectura", selection: Binding(get: { a.lecturaFecha ?? Fechas.hoy }, set: { a.lecturaFecha = $0 }), displayedComponents: .date)
                LabeledContent("Contador actual (h)") {
                    TextField("0", value: $a.horas, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
                LabeledContent("Horas de uso por día") {
                    TextField("Sin indicar", value: $a.usoHoras, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
            } header: { Text("Contador y uso") } footer: { Text("Para estimar los mantenimientos por horas.") }
        }

        Section {
            TextField("Fabricante", text: $a.fabricante)
            TextField("Modelo", text: $a.modelo)
            TextField("Número de serie", text: $a.numeroSerie)
            TextField("División o actividad", text: $a.division)
        } header: { Text("Ficha técnica") } footer: { Text("Los datos de la placa.") }

        Section("Repuestos") {
            TextField("Piezas y consumibles que usa", text: $a.repuestos, axis: .vertical).lineLimit(1...4)
        }
        Section("Notas") {
            TextField("Notas internas", text: $a.notas, axis: .vertical).lineLimit(1...4)
        }
        Section {
            ForEach(a.checklist.indices, id: \.self) { i in
                Label(a.checklist[i], systemImage: "circle")
            }
            .onDelete { a.checklist.remove(atOffsets: $0) }
            HStack {
                TextField("Añadir paso", text: $nuevoPaso).onSubmit(anadir)
                Button(action: anadir) { Image(systemName: "plus.circle.fill") }.disabled(nuevoPaso.isEmpty)
                    .accessibilityLabel(Text("Añadir paso"))
            }
        } header: { Text("Checklist") } footer: { Text("Guía de lo que el técnico tiene que comprobar si el mantenimiento no trae otra. La ve en su orden de trabajo y sale en el parte.") }
    }

    private func anadir() {
        let p = nuevoPaso.trimmingCharacters(in: .whitespaces)
        guard !p.isEmpty else { return }
        a.checklist.append(p)
        nuevoPaso = ""
    }
}

/// Mantenimiento nuevo o editar: qué, cada cuánto, quién, checklist y más opciones.
/// Al guardar, la base crea sola su OT con la fecha estimada.
struct PlanForm: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var dismiss
    let original: PlanMantenimiento
    let nuevo: Bool
    @State private var p: PlanMantenimiento
    @State private var porHoras: Bool
    @State private var automaticas = true
    @State private var mas = false
    @State private var nuevoPaso = ""
    @State private var borrar = false

    init(original: PlanMantenimiento, nuevo: Bool) {
        self.original = original
        self.nuevo = nuevo
        _p = State(initialValue: original)
        _porHoras = State(initialValue: original.cadaHoras != nil)
    }

    private let atajos: [(LocalizedStringKey, Int)] = [("Cada día", 1), ("Cada semana", 7), ("Cada mes", 30), ("Cada 2 meses", 60), ("Cada trimestre", 91), ("Cada 6 meses", 182), ("Cada año", 365)]

    private var puede: Bool { !p.nombre.trimmingCharacters(in: .whitespaces).isEmpty && (p.cadaDias != nil || p.cadaHoras != nil) }

    private var estimado: String? {
        if porHoras {
            guard let h = p.cadaHoras, let a = almacen.raiz(p.activoId), a.usoHoras > 0 else { return nil }
            let dias = Int((Double(h) / a.usoHoras).rounded())
            return String(localized: "≈ \(Fechas.corta(Fechas.mas(Fechas.hoy, dias: dias))), en \(dias) días (estimado)")
        }
        guard let d = p.cadaDias else { return nil }
        let base = p.ultimo ?? Fechas.hoy
        let f = p.proximo ?? Fechas.mas(base, dias: d)
        return String(localized: "≈ \(Fechas.corta(f)), \(Fechas.relativo(f)) (estimado)")
    }

    var body: some View {
        Form {
            Section("Mantenimiento") {
                TextField("Nombre (cambio de aceite)", text: $p.nombre)
                TextField("Breve descripción (vaciar, cambiar filtro y rellenar)", text: $p.descripcion, axis: .vertical).lineLimit(1...3)
            }
            Section {
                Picker("Programar por", selection: $porHoras.animation()) {
                    Text("Días").tag(false)
                    Text("Horas de uso").tag(true)
                }
                .onChange(of: porHoras) { _, h in
                    if h { p.cadaHoras = p.cadaHoras ?? 500; p.cadaDias = nil } else { p.cadaDias = p.cadaDias ?? 30; p.cadaHoras = nil }
                }
                if porHoras {
                    LabeledContent("Cada cuántas horas") {
                        TextField("500", value: $p.cadaHoras, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    }
                } else {
                    Picker("Cada cuánto", selection: Binding(get: { p.cadaDias ?? 30 }, set: { p.cadaDias = $0 })) {
                        ForEach(atajos, id: \.1) { Text($0.0).tag($0.1) }
                        if let d = p.cadaDias, !atajos.contains(where: { $0.1 == d }) { Text("Cada \(d) días").tag(d) }
                    }
                    Stepper("Cada \(p.cadaDias ?? 30) días", value: Binding(get: { p.cadaDias ?? 30 }, set: { p.cadaDias = $0 }), in: 1...3650)
                }
                DatePicker("Último hecho", selection: Binding(get: { p.ultimo ?? Fechas.hoy }, set: { p.ultimo = $0 }), displayedComponents: .date)
            } header: { Text("Cada cuánto") } footer: {
                if let estimado { Text(estimado) } else { Text("Por días, horas de uso o una fecha.") }
            }
            Section {
                Picker("Asignar a", selection: Binding(
                    get: { p.trabajadorId.map { "t:" + $0 } ?? p.grupoId.map { "g:" + $0 } ?? "" },
                    set: { v in
                        p.trabajadorId = v.hasPrefix("t:") ? String(v.dropFirst(2)) : nil
                        p.grupoId = v.hasPrefix("g:") ? String(v.dropFirst(2)) : nil
                    })) {
                    Text("Sin asignar").tag("")
                    if !almacen.grupos.isEmpty {
                        Section("Grupos") { ForEach(almacen.grupos) { Text($0.nombre).tag("g:" + $0.id) } }
                    }
                    Section("Técnicos") { ForEach(almacen.tecnicos.filter(\.activo)) { Text($0.nombreCompleto).tag("t:" + $0.id) } }
                }
                Picker("Duración", selection: Binding(get: { p.duracionMin ?? 60 }, set: { p.duracionMin = $0 })) {
                    ForEach([15, 30, 45, 60, 90, 120, 180, 240, 480], id: \.self) { m in
                        Text(m < 60 ? "\(m) min" : m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60) min").tag(m)
                    }
                }
            } header: { Text("Quién") } footer: { Text("Sus órdenes se asignan aquí. Si es un grupo, al técnico más libre.") }
            Section {
                ForEach(p.checklist.indices, id: \.self) { i in Label(p.checklist[i], systemImage: "circle") }
                    .onDelete { p.checklist.remove(atOffsets: $0) }
                    .onMove { p.checklist.move(fromOffsets: $0, toOffset: $1) }
                HStack {
                    TextField("Añadir paso", text: $nuevoPaso).onSubmit(anadir)
                    Button(action: anadir) { Image(systemName: "plus.circle.fill") }.disabled(nuevoPaso.isEmpty)
                        .accessibilityLabel(Text("Añadir paso"))
                }
            } header: { Text("Checklist") } footer: { Text("Guía de lo que el técnico tiene que comprobar. La ve en su orden de trabajo, marca cada paso y sale en el parte.") }
            Section {
                DisclosureGroup("Más opciones", isExpanded: $mas) {
                    TextField("Repuestos", text: $p.repuestos, axis: .vertical).lineLimit(1...3)
                    TextField("Procedimiento", text: $p.procedimiento, axis: .vertical).lineLimit(1...5)
                    TextField("Preparación", text: $p.preparar, axis: .vertical).lineLimit(1...3)
                    TextField("Medición (presión, temperatura…)", text: $p.medicionNombre)
                    if !p.medicionNombre.isEmpty {
                        TextField("Unidad (bar, ºC…)", text: $p.medicionUnidad)
                        LabeledContent("Mínimo") { TextField("—", value: $p.medicionMin, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                        LabeledContent("Máximo") { TextField("—", value: $p.medicionMax, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    }
                }
            } footer: { Text("Si la medición sale de sus límites, Pultec abre una incidencia sola.") }
            if nuevo {
                Section {
                    Toggle(isOn: $automaticas) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Crear las órdenes automáticamente")
                            Text("Pultec la crea sola cada vez que toca.").font(.app(.caption)).foregroundStyle(.secondary)
                        }
                    }
                } header: { Text("Órdenes de trabajo") }
            } else {
                Section {
                    Toggle("Vigente (crea sus órdenes)", isOn: $p.activa)
                    Button(role: .destructive) { borrar = true } label: { Label("Eliminar", systemImage: "trash") }.foregroundStyle(.red)
                }
            }
        }
        .fondoTema()
        .hojaFormulario(nuevo ? String(localized: "Nuevo mantenimiento") : p.nombre, puedeGuardar: puede && (nuevo || p != original)) {
            if nuevo { p.activa = automaticas }
            Task { await almacen.guardar(p); dismiss() }
        }
        .confirmationDialog("¿Eliminar «\(p.nombre)»?", isPresented: $borrar, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { Task { await almacen.borrar(plan: original); dismiss() } }
        } message: { Text("Se borran también sus órdenes pendientes.") }
    }

    private func anadir() {
        let x = nuevoPaso.trimmingCharacters(in: .whitespaces)
        guard !x.isEmpty else { return }
        p.checklist.append(x)
        nuevoPaso = ""
    }
}
