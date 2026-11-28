import SwiftUI

/// Ajustes generales: Cuenta, Plan, Automatizaciones, Apariencia, Empresa y Vista de técnico.
struct AjustesView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(AppEstado.self) private var estado
    @State private var verComo = false
    @State private var salir = false

    var body: some View {
        @Bindable var estado = estado
        Pila {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image("Logo").resizable().scaledToFit().frame(width: 44, height: 44)
                            .clipShape(.rect(cornerRadius: 11, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(almacen.empresaNombre).font(.app(.headline))
                            Text(almacen.correo).font(.app(.subheadline)).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Empresa") {
                    NavigationLink { EmpresaAjustes() } label: { Label("Empresa", systemImage: "building.2") }
                    NavigationLink { PlanAjustes() } label: { Label("Plan", systemImage: "rosette") }
                    NavigationLink { AutomatizacionesAjustes() } label: { Label("Automatizaciones", systemImage: "bolt") }
                }
                Section {
                    Picker(selection: $estado.tema) {
                        ForEach(Tema.allCases) { Text($0.nombre).tag($0) }
                    } label: { Label("Tema", systemImage: "circle.lefthalf.filled") }
                } header: { Text("Apariencia") } footer: { Text("El tamaño de la letra sigue al de tu iPhone (Ajustes › Pantalla y brillo).") }
                Section {
                    Button { verComo = true } label: { Label("Vista de técnico", systemImage: "person.badge.key") }
                } footer: { Text("Así verá Pultec cada técnico en su móvil.") }
                Section {
                    Link(destination: URL(string: Configuracion.web)!) {
                        HStack(spacing: 5) {
                            Text("Web de Pultec")
                            Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .bold)).accessibilityHidden(true)
                        }
                    }
                    Button("Cerrar sesión", role: .destructive) { salir = true }
                } footer: {
                    Text("Pultec \(Bundle.main.versionCompleta)").frame(maxWidth: .infinity).padding(.top, 8)
                }
            }
            .fondoTema()
            .tituloPantalla("Ajustes", icono: "gearshape")
            .sheet(isPresented: $verComo) { VerComoView() }
            .confirmationDialog("¿Cerrar sesión?", isPresented: $salir) {
                Button("Cerrar sesión", role: .destructive) { Task { await almacen.salir() } }
            }
        }
    }
}

/// «Ver Pultec como…»: elegir técnico para ver su app.
struct VerComoView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(almacen.tecnicos.filter(\.activo)) { w in
                        Button {
                            dismiss()
                            withAnimation { almacen.viendoComo = w.id }
                        } label: {
                            HStack(spacing: 12) {
                                Avatar(tecnico: w, tamano: 34, conEstado: true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(w.nombreCompleto).font(.app(.body, .medium))
                                    let n = almacen.ordenesDe(tecnico: w.id).filter { $0.estado.abierta }.count
                                    Text(n == 1 ? "Una orden de trabajo asignada" : "\(n) órdenes de trabajo asignadas")
                                        .font(.app(.caption)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                } footer: { Text("Así lo verá cada técnico en su móvil.") }
            }
            .fondoTema()
            .hojaConsulta(String(localized: "Ver Pultec como…"))
        }
    }
}

private struct EmpresaAjustes: View {
    @Environment(Almacen.self) private var almacen
    @State private var nombre = ""

    var body: some View {
        Form {
            Section("Nombre de la empresa") {
                TextField("Nombre", text: $nombre).onSubmit { Task { await almacen.renombrarEmpresa(nombre) } }
            }
            Section("En Pultec") {
                LabeledContent("Activos", value: "\(almacen.activos.count)")
                LabeledContent("Técnicos", value: "\(almacen.tecnicos.count)")
                LabeledContent("Mantenimientos", value: "\(almacen.planes.count)")
            }
        }
        .fondoTema()
        .navigationTitle("Empresa")
        .onAppear { nombre = almacen.empresaNombre }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BotonConfirmar(activo: !nombre.isEmpty && nombre != almacen.empresaNombre) {
                    Task { await almacen.renombrarEmpresa(nombre) }
                }
            }
        }
    }
}

private struct PlanAjustes: View {
    @Environment(Almacen.self) private var almacen
    @State private var plan: (nombre: String, estado: String?, fin: Date?)?

    var body: some View {
        List {
            Section {
                if let plan {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.nombre).font(.app(.headline))
                            if plan.nombre == "Premium" { Text("49 € al mes + IVA").font(.app(.subheadline)).foregroundStyle(.secondary) }
                            if let fin = plan.fin { Text("Se renueva el \(Fechas.corta(fin))").font(.app(.caption)).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        if plan.estado == "active" { Insignia(texto: "Activo", color: .pVerde) }
                    }
                } else {
                    ProgressView()
                }
            } footer: { Text("El plan y las facturas se gestionan en la web de Pultec.") }
        }
        .fondoTema()
        .navigationTitle("Plan")
        .task { plan = await almacen.planEmpresa() }
    }
}

private struct AutomatizacionesAjustes: View {
    @Environment(Almacen.self) private var almacen
    @State private var avisos: [Almacen.AvisoCorreo] = []
    @State private var nuevo: [String: String] = [:]

    private let eventos: [(String, LocalizedStringKey, LocalizedStringKey)] = [
        ("incidencia", "Cuando hay una incidencia", "Cualquier incidencia nueva, de cualquier gravedad, la avisa un técnico o la oficina."),
        ("ot_vencida", "Cuando vence una orden de trabajo", "Cuando pasa su fecha sin completarse. Un correo por orden."),
    ]

    var body: some View {
        List {
            ForEach(eventos, id: \.0) { evento, titulo, detalle in
                Section {
                    ForEach(avisos.filter { $0.evento == evento }) { a in
                        Label(a.correo, systemImage: "envelope")
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await almacen.borrarAvisoCorreo(a.id); avisos = await almacen.avisosCorreo() }
                                } label: { Label("Borrar", systemImage: "trash") }
                            }
                    }
                    HStack {
                        TextField("correo@empresa.com", text: Binding(get: { nuevo[evento, default: ""] }, set: { nuevo[evento] = $0 }))
                            .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                        Button {
                            let c = nuevo[evento, default: ""]
                            Task { await almacen.crearAvisoCorreo(evento, c); nuevo[evento] = ""; avisos = await almacen.avisosCorreo() }
                        } label: { Image(systemName: "plus.circle.fill") }
                            .disabled(!nuevo[evento, default: ""].contains("@"))
                            .accessibilityLabel(Text("Añadir correo"))
                    }
                } header: { Text(titulo) } footer: { Text(detalle) }
            }
        }
        .fondoTema()
        .navigationTitle("Automatizaciones")
        .task { avisos = await almacen.avisosCorreo() }
    }
}
