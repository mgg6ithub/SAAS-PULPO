import SwiftUI

/// PDF del parte (como el de la web: empresa, número, orden, activo, resultado, trabajo, fotos y firma)
/// y exportación de listas a CSV (abre en Excel o Numbers).
enum Documentos {
    /// Genera el PDF A4 del parte y devuelve su archivo temporal.
    @MainActor
    static func pdfParte(_ almacen: Almacen, ot: OrdenTrabajo?, informe: Informe, fotos: [UIImage], firma: UIImage?) -> URL? {
        let vista = PartePDF(almacen: almacen, ot: ot, informe: informe, fotos: fotos, firma: firma)
            .frame(width: 595, height: 842)
        let r = ImageRenderer(content: vista)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Parte \(ot?.nombre ?? "OT") \(Fechas.texto(informe.cuando)).pdf")
        var caja = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let ctx = CGContext(url as CFURL, mediaBox: &caja, nil) else { return nil }
        r.render { _, dibujar in
            ctx.beginPDFPage(nil)
            dibujar(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
        }
        return url
    }

    /// CSV con separador «;» (Excel en español) y BOM para que lea bien las tildes.
    static func csv(_ nombre: String, _ cabecera: [String], _ filas: [[String]]) -> URL {
        func campo(_ s: String) -> String {
            s.contains(";") || s.contains("\"") || s.contains("\n") ? "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\"" : s
        }
        let texto = ([cabecera] + filas).map { $0.map(campo).joined(separator: ";") }.joined(separator: "\r\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(nombre).csv")
        try? (Data([0xEF, 0xBB, 0xBF]) + Data(texto.utf8)).write(to: url)
        return url
    }

    @MainActor
    static func csvActivos(_ a: Almacen) -> URL {
        csv("Activos", ["Activo", "Tag", "Componente de", "Horas", "Uso h/día", "Mantenimientos", "Fabricante", "Modelo", "Nº de serie"],
            a.activos.map { x in
                [x.nombre, x.tag, a.activo(x.padreId)?.nombreCompleto ?? "", "\(Int(x.horasHoy))", "\(Int(x.usoHoras))",
                 "\(a.planesDe(x.id).count)", x.fabricante, x.modelo, x.numeroSerie]
            })
    }

    @MainActor
    static func csvOrdenes(_ a: Almacen) -> URL {
        csv("Órdenes de trabajo", ["Orden", "Activo", "Origen", "Criticidad", "Técnico", "Fecha", "Estado"],
            a.ordenes.map { o in
                [o.nombre, a.activo(o.activoId)?.nombreCompleto ?? "", a.origenTexto(o),
                 o.criticidad.texto, a.tecnico(o.tecnicoIds.first)?.nombreCompleto ?? "",
                 (o.proximo ?? o.ultimo).map(Fechas.corta) ?? "", o.estado.texto]
            })
    }

    @MainActor
    static func csvTecnicos(_ a: Almacen) -> URL {
        csv("Técnicos", ["Nombre", "Apellidos", "Teléfono", "Email", "Grupos", "Hoy"],
            a.tecnicos.map { w in
                [w.nombre, w.apellidos, w.telefono, w.email, w.grupoIds.compactMap { a.grupo($0)?.nombre }.joined(separator: ", "),
                 w.estadoHoy.texto]
            })
    }

    @MainActor
    static func csvIncidencias(_ a: Almacen) -> URL {
        csv("Incidencias", ["Incidencia", "Activo", "Gravedad", "Estado", "Comunicada por", "Fecha"],
            a.incidencias.map { i in
                [i.descripcion, a.activo(i.activoId)?.nombreCompleto ?? "", i.gravedad.texto,
                 i.estado.texto, a.tecnico(i.tecnicoId)?.nombreCompleto ?? "", Fechas.corta(i.creada)]
            })
    }
}

/// Página del parte en PDF.
private struct PartePDF: View {
    let almacen: Almacen
    let ot: OrdenTrabajo?
    let informe: Informe
    let fotos: [UIImage]
    let firma: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image("Logo").resizable().frame(width: 36, height: 36).clipShape(.rect(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(almacen.empresaNombre).font(.system(size: 13, weight: .semibold))
                    Text("Parte de orden de trabajo").font(.system(size: 10)).foregroundStyle(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("OT-\(String((ot?.id ?? informe.trabajoId).prefix(8)).uppercased())").font(.system(size: 11, weight: .semibold))
                    Text(informe.cuando.formatted(date: .numeric, time: .shortened)).font(.system(size: 10)).foregroundStyle(.gray)
                }
            }
            Divider()
            Text(ot?.nombre ?? "").font(.system(size: 20, weight: .bold))
            if let d = ot?.descripcion, !d.isEmpty { Text(d).font(.system(size: 11)).foregroundStyle(.gray) }
            Text(informe.resultado.texto).font(.system(size: 11, weight: .semibold)).foregroundStyle(informe.resultado.color)
                .padding(.horizontal, 8).padding(.vertical, 3).background(informe.resultado.color.opacity(0.12), in: .capsule)
            HStack(alignment: .top, spacing: 12) {
                bloque("Orden de trabajo", [
                    ("Criticidad", ot?.criticidad.texto ?? "—"),
                    ("Origen", ot.map { almacen.origenTexto($0) } ?? "—"),
                    ("Mantenimiento", almacen.plan(ot?.planId).map { "\($0.nombre), \($0.cadaCuanto)" } ?? "—"),
                    ("Asignado a", almacen.tecnico(ot?.tecnicoIds.first)?.nombreCompleto ?? "—"),
                ])
                bloque("Activo", [
                    ("Activo", almacen.activo(ot?.activoId)?.nombreCompleto ?? "—"),
                    ("Fabricante y modelo", almacen.activo(ot?.activoId).map { "\($0.fabricante) \($0.modelo)" } ?? "—"),
                ])
            }
            bloque("Trabajo", filasTrabajo)
            if !fotos.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(fotos.prefix(4).enumerated()), id: \.offset) { _, f in
                        Image(uiImage: f).resizable().scaledToFill().frame(width: 120, height: 90).clipped().clipShape(.rect(cornerRadius: 6))
                    }
                }
            }
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    if let firma { Image(uiImage: firma).resizable().scaledToFit().frame(width: 160, height: 60) }
                    Rectangle().frame(width: 180, height: 0.5)
                    Text("Firma del responsable").font(.system(size: 9)).foregroundStyle(.gray)
                }
            }
            Text("Generado con Pultec").font(.system(size: 8)).foregroundStyle(.gray).frame(maxWidth: .infinity)
        }
        .padding(36)
        .background(.white)
        .foregroundStyle(.black)
        .environment(\.colorScheme, .light)
    }

    private var filasTrabajo: [(String, String)] {
        var f: [(String, String)] = []
        f.append(("Realizado el", informe.cuando.formatted(date: .numeric, time: .shortened)))
        f.append(("Técnico", almacen.tecnico(informe.trabajadorId)?.nombreCompleto ?? "—"))
        f.append(("Tiempo", informe.minutos.map { "\($0) min" } ?? "—"))
        f.append(("Qué se hizo", informe.notas.isEmpty ? "—" : informe.notas))
        f.append(("Repuestos", informe.material.isEmpty ? "—" : informe.material))
        if let v = informe.valor { f.append(("Medición", v.formatted())) }
        return f
    }

    private func bloque(_ titulo: String, _ filas: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundStyle(.gray)
            ForEach(filas, id: \.0) { k, v in
                VStack(alignment: .leading, spacing: 1) {
                    Text(k).font(.system(size: 8)).foregroundStyle(.gray)
                    Text(v).font(.system(size: 11))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.gray.opacity(0.3), lineWidth: 0.5))
    }
}

/// Exportar a CSV (Ajustes › Datos y listas).
struct ExportarView: View {
    @Environment(Almacen.self) private var almacen

    var body: some View {
        List {
            Section {
                ShareLink(item: Documentos.csvActivos(almacen)) { Label("Activos", systemImage: "gearshape.2") }
                ShareLink(item: Documentos.csvOrdenes(almacen)) { Label("Órdenes de trabajo", systemImage: "list.clipboard") }
                ShareLink(item: Documentos.csvTecnicos(almacen)) { Label("Técnicos", systemImage: "person.2") }
                ShareLink(item: Documentos.csvIncidencias(almacen)) { Label("Incidencias", systemImage: "exclamationmark.circle") }
            } footer: { Text("En CSV, con las mismas columnas que la lista. Se abre en Excel o Numbers. Importar, de momento, desde la web.") }
        }
        .fondoTema()
        .navigationTitle("Exportar")
    }
}
