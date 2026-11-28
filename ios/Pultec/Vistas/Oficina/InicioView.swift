import SwiftUI

/// Inicio: el resumen del día. Incidencias abiertas, cifras (Para hoy, Sin asignar,
/// Vencidos, Histórico), órdenes por criticidad, carga del equipo y esta semana.
struct InicioView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(AppEstado.self) private var estado
    @State private var criticidad: Criticidad = .preventivo
    @State private var incidencia: Incidencia?
    @State private var ot: OrdenTrabajo?

    private let columnas = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    cabecera
                    if !almacen.incidenciasAbiertas.isEmpty { incidenciasAbiertas }
                    cifras
                    ordenesPorCriticidad
                    cargaEquipo
                    estaSemana
                }
                .padding(16)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .refreshable { await almacen.recargar() }
            .fondoTema()
            .tituloPantalla("Inicio", icono: "house")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { BotonAvisos() } }
            .sheet(item: $incidencia) { IncidenciaView(incidencia: $0) }
            .sheet(item: $ot) { o in NavigationStack { OTDetalleView(otId: o.id) } }
        }
    }

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hoy es \(Fechas.larga(Date()))").font(.app(.subheadline)).foregroundStyle(.secondary)
            Text(almacen.empresaNombre).font(.system(size: 30, weight: .bold))
            Text(fraseDelDia).font(.app(.subheadline)).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    contador("gearshape.2", almacen.raices.count, "activos")
                    contador("list.clipboard", almacen.pendientes.count, "órdenes de trabajo")
                    contador("person.2", almacen.tecnicos.count, "técnicos")
                    contador("exclamationmark.circle", almacen.incidenciasAbiertas.count,
                             almacen.incidenciasAbiertas.isEmpty ? "Sin incidencias" : "incidencias")
                }
            }
            .padding(.top, 6)
        }
    }

    private var fraseDelDia: LocalizedStringKey {
        let hoy = almacen.pendientes.filter(\.paraHoy).count
        let vencidas = almacen.pendientes.filter(\.vencida).count
        if hoy == 0 && vencidas > 0 { return "Hoy no hay nada programado: buen momento para ponerte al día con lo vencido." }
        if hoy == 0 { return "Hoy no hay nada programado." }
        return hoy == 1 ? "Hoy toca una orden de trabajo." : "Hoy tocan \(hoy) órdenes de trabajo."
    }

    private func contador(_ icono: String, _ n: Int, _ texto: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icono).font(.caption)
            if n > 0 || icono != "exclamationmark.circle" { Text("\(n)").font(.app(.subheadline, .semibold)) }
            Text(texto).font(.app(.subheadline)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.background.secondary, in: .capsule)
    }

    private var incidenciasAbiertas: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle").foregroundStyle(Color.pRojo)
                EncabezadoBloque(titulo: "Incidencias abiertas", cifra: almacen.incidenciasAbiertas.count, color: .pRojo)
            }
            ForEach(almacen.incidenciasAbiertas.prefix(4)) { i in
                Tarjeta(relleno: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(almacen.activo(i.activoId)?.nombreCompleto ?? "").font(.app(.caption)).foregroundStyle(.secondary)
                            Text(i.descripcion).font(.app(.body, .semibold)).lineLimit(2)
                            HStack(spacing: 6) {
                                Insignia(texto: i.gravedad.etiqueta, color: i.gravedad.color)
                                Text("\(almacen.tecnico(i.tecnicoId)?.nombre ?? String(localized: "Oficina")), \(Fechas.relativo(i.creada))")
                                    .font(.app(.caption)).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Revisar") { incidencia = i }.buttonStyle(.glass).controlSize(.small)
                    }
                }
            }
        }
    }

    private var cifras: some View {
        LazyVGrid(columns: columnas, spacing: 12) {
            boton(.hoy) { TarjetaCifra(titulo: "Para hoy", valor: almacen.pendientes.filter(\.paraHoy).count, subtitulo: "en agenda", icono: "calendar", color: .pMorado) }
            boton(.sinAsignar) { TarjetaCifra(titulo: "Sin asignar", valor: almacen.pendientes.filter { $0.tecnicoIds.isEmpty }.count, subtitulo: "órdenes por asignar", icono: "person.crop.circle.badge.xmark", color: .pGris) }
            boton(.vencidos) { TarjetaCifra(titulo: "Vencidos", valor: almacen.pendientes.filter(\.vencida).count, subtitulo: "requieren atención", icono: "exclamationmark.triangle", color: .pRojo) }
            boton(.historico) { TarjetaCifra(titulo: "Histórico", valor: almacen.historico.count, subtitulo: "órdenes cerradas", icono: "checkmark.circle", color: .pVerde) }
        }
    }

    private func boton(_ filtro: FiltroRapido, @ViewBuilder _ contenido: () -> some View) -> some View {
        Button {
            estado.filtroOrdenes = filtro
            estado.pestana = .ordenes
        } label: { contenido() }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: estado.filtroOrdenes)
    }

    private var ordenesPorCriticidad: some View {
        let lista = almacen.pendientes.filter { $0.criticidad == criticidad }
        return VStack(alignment: .leading, spacing: 12) {
            EncabezadoBloque(titulo: "Órdenes de trabajo")
            Picker("Criticidad", selection: $criticidad) {
                ForEach(Criticidad.allCases) { c in
                    Text("\(Text(c.corta)) \(almacen.pendientes.filter { $0.criticidad == c }.count)").tag(c)
                }
            }
            .pickerStyle(.segmented)
            Tarjeta(relleno: 4) {
                if lista.isEmpty {
                    Text("Ninguna pendiente").font(.app(.subheadline)).foregroundStyle(.secondary).padding(12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(lista.prefix(5)) { o in
                            Button { ot = o } label: { FilaOT(ot: o).padding(12) }.buttonStyle(.plain)
                            if o.id != lista.prefix(5).last?.id { Divider().padding(.leading, 42) }
                        }
                        if lista.count > 5 {
                            Button("Ver todas (\(lista.count))") {
                                estado.filtroOrdenes = .todos
                                estado.pestana = .ordenes
                            }
                            .font(.app(.subheadline, .medium)).padding(12)
                        }
                    }
                }
            }
        }
    }

    private var cargaEquipo: some View {
        let lista = almacen.tecnicos.filter(\.activo).map { ($0, almacen.carga($0.id)) }.sorted { $0.1 > $1.1 }.prefix(8)
        let maximo = max(1, lista.map(\.1).max() ?? 1)
        return VStack(alignment: .leading, spacing: 10) {
            EncabezadoBloque(titulo: "Carga del equipo")
            Text("Órdenes de trabajo asignadas en los próximos 7 días").font(.app(.caption)).foregroundStyle(.secondary)
            Tarjeta {
                VStack(spacing: 12) {
                    ForEach(lista, id: \.0.id) { w, n in
                        NavigationLink { TecnicoDetalleView(tecnicoId: w.id) } label: {
                            HStack(spacing: 10) {
                                Avatar(tecnico: w, tamano: 26, conEstado: true)
                                Text(w.nombreCompleto).font(.app(.subheadline)).lineLimit(1).frame(width: 130, alignment: .leading)
                                GeometryReader { g in
                                    Capsule().fill(Color.gray.opacity(0.15))
                                        .overlay(alignment: .leading) {
                                            Capsule().fill(w.colorSwift).frame(width: g.size.width * CGFloat(n) / CGFloat(maximo))
                                        }
                                }
                                .frame(height: 6)
                                Text("\(n)").font(.app(.subheadline, .semibold)).frame(width: 24, alignment: .trailing)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var estaSemana: some View {
        let dias = (0..<7).map { Fechas.mas(Fechas.hoy, dias: $0) }
        let cuenta = dias.map { d in almacen.pendientes.filter { $0.proximo.map { Calendar.current.isDate($0, inSameDayAs: d) } ?? false }.count }
        let maximo = max(1, cuenta.max() ?? 1)
        return VStack(alignment: .leading, spacing: 10) {
            EncabezadoBloque(titulo: "Esta semana")
            Tarjeta {
                VStack(spacing: 10) {
                    ForEach(Array(dias.enumerated()), id: \.offset) { n, d in
                        HStack(spacing: 10) {
                            Text(n == 0 ? String(localized: "Hoy") : n == 1 ? String(localized: "Mañana") : d.formatted(.dateTime.weekday(.wide)))
                                .font(.app(.subheadline)).frame(width: 90, alignment: .leading)
                            Text(d.formatted(.dateTime.day())).font(.app(.caption)).foregroundStyle(.secondary).frame(width: 22)
                            GeometryReader { g in
                                Capsule().fill(Color.gray.opacity(0.15))
                                    .overlay(alignment: .leading) {
                                        Capsule().fill(Color.pMorado).frame(width: g.size.width * CGFloat(cuenta[n]) / CGFloat(maximo))
                                    }
                            }
                            .frame(height: 6)
                            Text("\(cuenta[n])").font(.app(.subheadline, .semibold)).frame(width: 28, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
}
