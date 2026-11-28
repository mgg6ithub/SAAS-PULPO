import SwiftUI
import Charts

/// Estadísticas: Activo · Indicadores · Técnicos · Incidencias; periodo 30 días / 3 meses / Año.
struct EstadisticasView: View {
    @Environment(Almacen.self) private var almacen
    @State private var apartado = 0
    @State private var periodo = 90

    private var desde: Date { Fechas.mas(Fechas.hoy, dias: -periodo) }
    private var hechas: [OrdenTrabajo] {
        almacen.ordenes.filter { $0.estado == .completada && ($0.completadaEl ?? $0.ultimo ?? .distantPast) >= desde }
    }
    private var incidenciasPeriodo: [Incidencia] { almacen.incidencias.filter { $0.creada >= desde } }
    private let columnas = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        Pila {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Apartado", selection: $apartado.animation()) {
                        Text("Activo").tag(0)
                        Text("Indicadores").tag(1)
                        Text("Técnicos").tag(2)
                        Text("Incidencias").tag(3)
                    }
                    .pickerStyle(.segmented)
                    Picker("Periodo", selection: $periodo) {
                        Text("30 días").tag(30)
                        Text("3 meses").tag(90)
                        Text("Año").tag(365)
                    }
                    .pickerStyle(.segmented)
                    switch apartado {
                    case 0: activo
                    case 1: indicadores
                    case 2: tecnicos
                    default: incidencias
                    }
                }
                .padding(16)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .fondoTema()
            .tituloPantalla("Estadísticas", icono: "chart.xyaxis.line")
        }
    }

    private func cifra(_ titulo: LocalizedStringKey, _ valor: String, _ ayuda: LocalizedStringKey, color: Color = .primary) -> some View {
        Tarjeta(relleno: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(titulo).font(.app(.caption)).foregroundStyle(.secondary)
                    Image(systemName: "info.circle").font(.caption2).foregroundStyle(.tertiary).help(Text(ayuda))
                }
                Text(valor).font(.system(size: 26, weight: .semibold)).foregroundStyle(color)
            }
        }
    }

    private func semanas<T>(_ lista: [T], fecha: (T) -> Date?) -> [(Date, Int)] {
        let cal = Calendar.current
        var cuenta: [Date: Int] = [:]
        for x in lista { if let f = fecha(x), let s = cal.dateInterval(of: .weekOfYear, for: f)?.start { cuenta[s, default: 0] += 1 } }
        var r: [(Date, Int)] = []
        var s = cal.dateInterval(of: .weekOfYear, for: desde)?.start ?? desde
        while s <= Fechas.hoy { r.append((s, cuenta[s] ?? 0)); s = Fechas.mas(s, dias: 7) }
        return r
    }

    // MARK: Activo

    @ViewBuilder
    private var activo: some View {
        let pendientes = almacen.pendientes.count
        let atrasadas = almacen.pendientes.filter(\.vencida).count
        LazyVGrid(columns: columnas, spacing: 12) {
            cifra("Hechas en el periodo", "\(hechas.count)", "Órdenes cerradas en el periodo.")
            cifra("Pendientes", "\(pendientes)", "Órdenes abiertas ahora.")
            cifra("Atrasadas", "\(atrasadas)", "Pendientes con la fecha pasada.", color: atrasadas > 0 ? .pRojo : .primary)
            cifra("Incidencias", "\(incidenciasPeriodo.count)", "Comunicadas en el periodo.")
        }
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                Text("Órdenes hechas").font(.app(.headline))
                Text("Por semana").font(.app(.caption)).foregroundStyle(.secondary)
                Chart(semanas(hechas) { $0.completadaEl ?? $0.ultimo }, id: \.0) {
                    BarMark(x: .value("Semana", $0.0, unit: .weekOfYear), y: .value("Hechas", $0.1)).foregroundStyle(Color.pMorado)
                }
                .frame(height: 160)
            }
        }
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                Text("Estado de las órdenes").font(.app(.headline))
                let datos: [(String, Int, Color)] = [
                    (String(localized: "Hechas"), hechas.count, .pMorado),
                    (String(localized: "Pendientes al día"), pendientes - atrasadas, .gray.opacity(0.4)),
                    (String(localized: "Atrasadas"), atrasadas, .pRojo),
                ]
                HStack(spacing: 20) {
                    Chart(datos, id: \.0) { SectorMark(angle: .value("N", $0.1), innerRadius: .ratio(0.7)).foregroundStyle($0.2) }
                        .frame(width: 120, height: 120)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(datos, id: \.0) { d in
                            HStack { Capsule().fill(d.2).frame(width: 10, height: 3); Text(d.0).font(.app(.subheadline)); Spacer(); Text("\(d.1)").bold() }
                        }
                    }
                }
            }
        }
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                Text("Mantenimientos \(almacen.planes.count)").font(.app(.headline))
                ForEach(almacen.planes.prefix(30)) { p in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.nombre).font(.app(.subheadline, .medium))
                            Text(almacen.activo(p.activoId)?.nombreCompleto ?? "").font(.app(.caption)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(p.cadaCuanto).font(.app(.caption))
                            if let f = almacen.otAbierta(de: p)?.proximo { Text(Fechas.relativo(f)).font(.app(.caption)).foregroundStyle(.secondary) }
                        }
                    }
                    Divider()
                }
            }
        }
    }

    // MARK: Indicadores

    @ViewBuilder
    private var indicadores: some View {
        let preventivas = hechas.filter { $0.criticidad == .preventivo }.count
        let correctivas = hechas.count - preventivas
        let averias = incidenciasPeriodo.filter { $0.gravedad == .grave }.count
        let planificadas = hechas.count + almacen.pendientes.filter(\.vencida).count
        LazyVGrid(columns: columnas, spacing: 12) {
            cifra("MTBF entre averías", averias == 0 ? String(localized: "Sin averías") : "\(periodo * 24 / max(averias, 1)) h",
                  "Tiempo medio entre averías graves.")
            cifra("Preventivo", hechas.isEmpty ? "—" : "\(preventivas * 100 / max(hechas.count, 1)) %", "Parte de las órdenes hechas que fueron preventivas.")
            cifra("Cumplimiento del plan", planificadas == 0 ? "—" : "\(hechas.count * 100 / max(planificadas, 1)) %",
                  "Hechas frente a las que tocaban.")
        }
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                Text("Preventivo frente a correctivo").font(.app(.headline))
                Chart {
                    BarMark(x: .value("N", preventivas), y: .value("Tipo", String(localized: "Preventivo"))).foregroundStyle(Color.pVerde)
                    BarMark(x: .value("N", correctivas), y: .value("Tipo", String(localized: "Correctivo"))).foregroundStyle(Color.pAmbar)
                }
                .frame(height: 100)
            }
        }
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                Text("Menos disponibles").font(.app(.headline))
                Text("Activos con más incidencias graves abiertas").font(.app(.caption)).foregroundStyle(.secondary)
                let por = Dictionary(grouping: almacen.incidencias.filter { $0.estado.pendiente }, by: { almacen.raiz($0.activoId)?.id ?? "" })
                let lista = almacen.raices.map { ($0, por[$0.id]?.count ?? 0) }.sorted { $0.1 > $1.1 }.prefix(6)
                ForEach(lista, id: \.0.id) { a, n in
                    HStack {
                        Text(a.nombreCompleto).font(.app(.subheadline)).lineLimit(1)
                        Spacer()
                        Text(n == 0 ? "100 %" : "\(n) abiertas").font(.app(.subheadline, .medium)).foregroundStyle(n == 0 ? Color.pVerde : .pRojo)
                    }
                }
            }
        }
    }

    // MARK: Técnicos

    @ViewBuilder
    private var tecnicos: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                Text("Órdenes hechas por el equipo").font(.app(.headline))
                Chart(semanas(hechas) { $0.completadaEl ?? $0.ultimo }, id: \.0) {
                    LineMark(x: .value("Semana", $0.0, unit: .weekOfYear), y: .value("Hechas", $0.1)).foregroundStyle(Color.pMorado)
                    AreaMark(x: .value("Semana", $0.0, unit: .weekOfYear), y: .value("Hechas", $0.1)).foregroundStyle(Color.pMorado.opacity(0.1))
                }
                .frame(height: 160)
            }
        }
        Tarjeta {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quién hace más").font(.app(.headline))
                let filas = almacen.tecnicos.map { w in
                    (w, hechas.filter { $0.tecnicoIds.contains(w.id) }.count,
                     incidenciasPeriodo.filter { $0.tecnicoId == w.id }.count,
                     almacen.ordenesDe(tecnico: w.id).filter(\.vencida).count)
                }.sorted { $0.1 > $1.1 }
                ForEach(filas, id: \.0.id) { w, n, inc, atr in
                    HStack(spacing: 10) {
                        Avatar(tecnico: w, tamano: 26)
                        Text(w.nombreCompleto).font(.app(.subheadline)).lineLimit(1)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(n) hechas").font(.app(.subheadline, .medium))
                            HStack(spacing: 6) {
                                if inc > 0 { Text("\(inc) incidencias").foregroundStyle(.secondary) }
                                if atr > 0 { Text("\(atr) atrasadas").foregroundStyle(Color.pRojo) }
                            }
                            .font(.app(.caption))
                        }
                    }
                }
            }
        }
    }

    // MARK: Incidencias

    @ViewBuilder
    private var incidencias: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 10) {
                Text("Incidencias en el tiempo").font(.app(.headline))
                Chart(semanas(incidenciasPeriodo) { $0.creada }, id: \.0) {
                    BarMark(x: .value("Semana", $0.0, unit: .weekOfYear), y: .value("Incidencias", $0.1)).foregroundStyle(Color.pRojo)
                }
                .frame(height: 160)
            }
        }
        Tarjeta {
            let datos: [(String, Int, Color)] = [
                (String(localized: "Resueltas"), incidenciasPeriodo.filter { $0.estado == .completada }.count, .pVerde),
                (String(localized: "Abiertas"), incidenciasPeriodo.filter(\.estado.pendiente).count, .pRojo),
                (String(localized: "Desestimadas"), incidenciasPeriodo.filter { $0.estado == .desestimada }.count, .gray),
            ]
            VStack(alignment: .leading, spacing: 10) {
                Text("Cómo acabaron").font(.app(.headline))
                HStack(spacing: 20) {
                    Chart(datos, id: \.0) { SectorMark(angle: .value("N", max($0.1, 0)), innerRadius: .ratio(0.7)).foregroundStyle($0.2) }
                        .frame(width: 120, height: 120)
                        .overlay { Text("\(incidenciasPeriodo.count)").font(.title2.bold()) }
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(datos, id: \.0) { d in
                            HStack { Capsule().fill(d.2).frame(width: 10, height: 3); Text(d.0).font(.app(.subheadline)); Spacer(); Text("\(d.1)").bold() }
                        }
                    }
                }
            }
        }
        if incidenciasPeriodo.isEmpty {
            EstadoVacio(icono: "exclamationmark.circle", titulo: "Sin incidencias en este periodo")
        }
    }
}
