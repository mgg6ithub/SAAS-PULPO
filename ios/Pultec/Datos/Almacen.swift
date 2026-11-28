import SwiftUI
import Observation

/// Todos los datos de la empresa y las acciones sobre ellos. Lo que decide la base
/// (OT automáticas, siguiente OT al cerrar, incidencias del parte, estados de la
/// incidencia) lo sigue decidiendo la base: aquí solo se escribe lo mismo que la web.
@Observable
@MainActor
final class Almacen {
    enum Fase: Equatable { case comprobando, fuera, cargando, dentro, error(String) }

    var fase: Fase = .comprobando
    var correo = ""
    var empresaId = ""
    var empresaNombre = ""
    var esAdmin = false
    /// Ficha de técnico de la cuenta (cuentas de técnico).
    var miTecnicoId: String?
    /// La oficina viendo la app como un técnico («Ver Pultec como…»).
    var viendoComo: String?

    var activos: [Activo] = []
    var planes: [PlanMantenimiento] = []
    var ordenes: [OrdenTrabajo] = []
    var incidencias: [Incidencia] = []
    var tecnicos: [Tecnico] = []
    var grupos: [Grupo] = []
    var ultimaCarga: Date?

    /// Mensaje breve abajo («Incidencia enviada», «Cambios guardados»…).
    var toast: String?
    var toastError = false
    var leidos: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "pultec.leidos") ?? [])

    private let nube = Nube.compartida
    private var refresco: Task<Void, Never>?

    // MARK: Sesión

    func arrancar() async {
        #if DEBUG
        // Pruebas en el simulador: PULTEC_ENTRAR="correo:contraseña" entra solo con una cuenta de prueba local.
        if let e = ProcessInfo.processInfo.environment["PULTEC_ENTRAR"], let dos = e.firstIndex(of: ":") {
            await nube.salir()
            try? await nube.entrar(correo: String(e[..<dos]), contrasena: String(e[e.index(after: dos)...]))
        }
        #endif
        if await nube.sesion != nil {
            await abrirEmpresa()
        } else {
            fase = .fuera
        }
    }

    func entrar(correo: String, contrasena: String) async throws {
        try await nube.entrar(correo: correo, contrasena: contrasena)
        await abrirEmpresa()
    }

    func registrarse(correo: String, contrasena: String) async throws {
        try await nube.registrarse(correo: correo, contrasena: contrasena)
        await abrirEmpresa()
    }

    func recuperar(correo: String) async throws { try await nube.recuperar(correo: correo) }

    func salir() async {
        refresco?.cancel()
        await nube.salir()
        activos = []; planes = []; ordenes = []; incidencias = []; tecnicos = []; grupos = []
        viendoComo = nil
        fase = .fuera
    }

    private func abrirEmpresa() async {
        fase = .cargando
        do {
            correo = await nube.correo ?? ""
            let r = try await nube.rpc("entrar", ["p_codigo": NSNull(), "p_marca": Configuracion.marca])
            let fila = (r as? [[String: Any]])?.first ?? (r as? [String: Any]) ?? [:]
            guard let usuario = await nube.usuarioId else { throw ErrorNube(mensaje: "Sin sesión.") }
            let miembros = try await nube.filas("miembros",
                "select=empresa_id,rol,trabajador_id,empresas!inner(nombre,marca)&usuario_id=eq.\(usuario)&empresas.marca=eq.\(Configuracion.marca)")
            let elegida = fila["empresa"] as? String
            guard let m = miembros.first(where: { $0["empresa_id"] as? String == elegida })
                    ?? miembros.first(where: { $0["rol"] as? String == "admin" }) ?? miembros.first else {
                throw ErrorNube(mensaje: "Esta cuenta no tiene empresa en Pultec.")
            }
            empresaId = m["empresa_id"] as? String ?? ""
            esAdmin = (m["rol"] as? String) == "admin"
            miTecnicoId = m["trabajador_id"] as? String
            empresaNombre = (m["empresas"] as? [String: Any])?["nombre"] as? String ?? "Pultec"
            try await cargar()
            fase = .dentro
            #if DEBUG
            // Pruebas: PULTEC_COMO="Ana" abre la vista de técnico de esa persona.
            if let n = ProcessInfo.processInfo.environment["PULTEC_COMO"] {
                viendoComo = tecnicos.first { $0.nombre == n }?.id
            }
            #endif
            empezarRefresco()
        } catch {
            fase = .error(error.localizedDescription)
        }
    }

    // MARK: Carga

    func cargar() async throws {
        let e = "empresa_id=eq.\(empresaId)"
        async let a = nube.filas("activos", "select=*&\(e)&order=created_at")
        async let p = nube.filas("planes_mantenimiento", "select=*&\(e)&order=created_at")
        async let t = nube.filas("trabajos", "select=*&\(e)&padre_id=is.null&order=created_at")
        async let tt = nube.filas("trabajo_trabajadores", "select=trabajo_id,trabajador_id&\(e)")
        async let i = nube.filas("incidencias", "select=*&\(e)&order=created_at.desc")
        async let w = nube.filas("trabajadores", "select=*&\(e)&order=created_at")
        async let g = nube.filas("grupos", "select=*&\(e)&order=created_at")
        let (fa, fp, ft, ftt, fi, fw, fg) = try await (a, p, t, tt, i, w, g)
        var asignados: [String: [String]] = [:]
        for x in ftt {
            if let ot = x["trabajo_id"] as? String, let w = x["trabajador_id"] as? String { asignados[ot, default: []].append(w) }
        }
        activos = fa.map(Activo.init)
        planes = fp.map(PlanMantenimiento.init)
        ordenes = ft.map { var o = OrdenTrabajo($0); o.tecnicoIds = asignados[o.id] ?? []; return o }
        incidencias = fi.map(Incidencia.init)
        tecnicos = fw.map(Tecnico.init)
        grupos = fg.map(Grupo.init)
        ultimaCarga = Date()
    }

    func recargar() async {
        do { try await cargar() } catch { avisar(error.localizedDescription, error: true) }
    }

    /// Avisos «en vivo»: vuelve a leer cada 20 s mientras la app está abierta.
    private func empezarRefresco() {
        refresco?.cancel()
        refresco = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard let self, self.fase == .dentro else { continue }
                try? await self.cargar()
            }
        }
    }

    func avisar(_ texto: String, error: Bool = false) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { toast = texto; toastError = error }
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            if toast == texto { withAnimation { toast = nil } }
        }
    }

    private func intentar(_ ok: String? = nil, _ trabajo: () async throws -> Void) async {
        do {
            try await trabajo()
            try? await cargar()
            if let ok { avisar(ok) }
        } catch {
            avisar(error.localizedDescription, error: true)
        }
    }

    // MARK: Consultas

    func activo(_ id: String?) -> Activo? { activos.first { $0.id == id } }
    func plan(_ id: String?) -> PlanMantenimiento? { planes.first { $0.id == id } }
    func orden(_ id: String?) -> OrdenTrabajo? { ordenes.first { $0.id == id } }
    func tecnico(_ id: String?) -> Tecnico? { tecnicos.first { $0.id == id } }
    func grupo(_ id: String?) -> Grupo? { grupos.first { $0.id == id } }
    func incidencia(_ id: String?) -> Incidencia? { incidencias.first { $0.id == id } }

    var raices: [Activo] { activos.filter { $0.padreId == nil }.sorted { $0.nombreCompleto < $1.nombreCompleto } }
    func hijos(_ id: String) -> [Activo] { activos.filter { $0.padreId == id } }
    func planesDe(_ activoId: String) -> [PlanMantenimiento] { planes.filter { $0.activoId == activoId } }
    /// Mantenimientos del activo y de sus componentes (Vista general del activo, como la web).
    func planesConComponentes(_ activoId: String) -> [PlanMantenimiento] {
        let ids = Set(arbol(activoId))
        return planes.filter { ids.contains($0.activoId) }
    }

    /// El activo y todos sus componentes, a cualquier profundidad.
    func arbol(_ id: String) -> [String] {
        [id] + hijos(id).flatMap { arbol($0.id) }
    }

    /// Activo principal (sin padre): el que lleva el contador.
    func raiz(_ id: String?) -> Activo? {
        var a = activo(id)
        while let p = a?.padreId, let padre = activo(p) { a = padre }
        return a
    }

    /// «Activos / Bomba 1 / Bomba de bomba 1».
    func ruta(_ id: String) -> [Activo] {
        var r: [Activo] = []
        var a = activo(id)
        while let x = a { r.insert(x, at: 0); a = activo(x.padreId) }
        return r
    }

    var pendientes: [OrdenTrabajo] {
        ordenes.filter { $0.estado.abierta && $0.activa }.sorted(by: Almacen.porFecha)
    }
    var historico: [OrdenTrabajo] {
        ordenes.filter { $0.estado == .completada }
            .sorted { ($0.completadaEl ?? $0.ultimo ?? .distantPast) > ($1.completadaEl ?? $1.ultimo ?? .distantPast) }
    }
    var canceladas: [OrdenTrabajo] { ordenes.filter { $0.estado == .cancelada } }

    static func porFecha(_ a: OrdenTrabajo, _ b: OrdenTrabajo) -> Bool {
        let fa = a.proximo ?? .distantFuture, fb = b.proximo ?? .distantFuture
        return fa == fb ? (a.inicioMin ?? 0) < (b.inicioMin ?? 0) : fa < fb
    }

    func ordenesDe(activo id: String) -> [OrdenTrabajo] {
        let ids = Set(arbol(id))
        return ordenes.filter { $0.activoId.map(ids.contains) ?? false }
    }

    func ordenesDe(tecnico id: String) -> [OrdenTrabajo] { ordenes.filter { $0.tecnicoIds.contains(id) } }

    /// OT abierta de un mantenimiento.
    func otAbierta(de plan: PlanMantenimiento) -> OrdenTrabajo? {
        ordenes.filter { $0.planId == plan.id && $0.estado.abierta }.sorted(by: Almacen.porFecha).first
    }

    /// Origen de la OT: incidencia (rojo), mantenimiento o manual.
    func origen(_ t: OrdenTrabajo) -> (LocalizedStringKey, String, Color) {
        if incidencias.contains(where: { $0.trabajoId == t.id && $0.origenTrabajoId != t.id }) {
            return ("Incidencia", "exclamationmark.circle", .pRojo)
        }
        if t.planId != nil { return ("Mantenimiento", "doc.text", .secondary) }
        return ("Manual", "hand.raised", .pAzul)
    }

    func incidenciaDe(ot id: String) -> Incidencia? {
        incidencias.first { $0.trabajoId == id && $0.origenTrabajoId != id }
    }

    /// Incidencia avisada desde esta OT que aún espera a la oficina.
    func esperando(_ ot: OrdenTrabajo) -> Incidencia? {
        incidencias.first { $0.origenTrabajoId == ot.id && $0.estado == .abierta }
    }

    var incidenciasAbiertas: [Incidencia] { incidencias.filter { $0.estado == .abierta } }

    /// Ciclo del mantenimiento: 1 = recién hecho, 0 = le toca ya.
    func ciclo(_ p: PlanMantenimiento) -> Double {
        guard let prox = otAbierta(de: p)?.proximo ?? p.proximo else { return 1 }
        let total = Double(p.cadaDias ?? max(1, (p.cadaHoras ?? 24) / 12))
        let quedan = Double(Fechas.dias(desde: Fechas.hoy, hasta: prox))
        return min(1, max(0, quedan / max(total, 1)))
    }

    /// Técnico con menos OT abiertas en los próximos 7 días («El más adecuado»).
    func masAdecuado(grupo: String? = nil) -> Tecnico? {
        let candidatos = tecnicos.filter { $0.activo && $0.estadoHoy != .ausente && (grupo == nil || $0.grupoIds.contains(grupo!)) }
        return candidatos.min { carga($0.id) < carga($1.id) }
    }

    func carga(_ tecnicoId: String) -> Int {
        let limite = Fechas.mas(Fechas.hoy, dias: 7)
        return pendientes.filter { $0.tecnicoIds.contains(tecnicoId) && ($0.proximo ?? .distantFuture) <= limite }.count
    }

    // MARK: Avisos (campana)

    var avisos: [Aviso] {
        var r: [Aviso] = []
        if let yo = tecnicoActivo {
            for t in ordenes where t.tecnicoIds.contains(yo) && t.estado.abierta {
                if let i = incidencias.first(where: { $0.trabajoId == t.id && $0.origenTrabajoId != nil && $0.origenTrabajoId != t.id }),
                   let previa = orden(i.origenTrabajoId) {
                    r.append(Aviso(id: "int-\(t.id)", titulo: String(localized: "La oficina ha interrumpido «\(previa.nombre)»"),
                                   detalle: String(localized: "El trabajo sigue en «\(t.nombre)»"),
                                   cuando: i.creada, color: .pAmbar, destino: .ot(t.id)))
                }
            }
        } else {
            for i in incidencias where i.estado == .abierta {
                r.append(Aviso(id: "inc-\(i.id)", titulo: i.descripcion,
                               detalle: String(localized: "Incidencia en \(activo(i.activoId)?.nombreCompleto ?? "")"),
                               cuando: i.creada, color: i.gravedad.color, destino: .incidencia(i.id)))
            }
            for t in ordenes where t.estado == .completada && (t.completadaEl.map { Calendar.current.isDateInToday($0) } ?? false) {
                let quien = t.completadaPor ?? tecnico(t.tecnicoIds.first)?.nombre ?? ""
                r.append(Aviso(id: "hecha-\(t.id)", titulo: String(localized: "\(quien) completó \(t.nombre)"),
                               detalle: activo(t.activoId)?.nombreCompleto ?? "", cuando: t.completadaEl ?? Date(),
                               color: .pVerde, destino: .ot(t.id)))
            }
            let sinTecnico = pendientes.filter { $0.tecnicoIds.isEmpty && ($0.proximo ?? .distantFuture) <= Fechas.hoy }.count
            if sinTecnico > 0 {
                r.append(Aviso(id: "sin-\(Fechas.texto(Fechas.hoy))-\(sinTecnico)",
                               titulo: String(localized: "\(sinTecnico) órdenes de hoy o vencidas sin técnico"),
                               detalle: String(localized: "Asígnalas para que alguien las reciba"),
                               cuando: Fechas.hoy, color: .pAmbar, destino: .ordenesSinTecnico))
            }
        }
        return r.sorted { $0.cuando > $1.cuando }
    }

    var sinLeer: Int { avisos.filter { !leidos.contains($0.id) }.count }

    func marcarLeidos() {
        leidos.formUnion(avisos.map(\.id))
        UserDefaults.standard.set(Array(leidos), forKey: "pultec.leidos")
    }

    // MARK: Oficina: activos y mantenimientos

    func guardar(_ a: Activo) async {
        await intentar("Cambios guardados") {
            var f = a.fila
            f["empresa_id"] = empresaId
            try await nube.insertar("activos", f, upsert: true)
        }
    }

    /// Borra el activo con sus componentes, mantenimientos, OT e incidencias (como la web).
    func borrar(activo a: Activo) async {
        await intentar("Activo borrado") {
            let ids = arbol(a.id).joined(separator: ",")
            try await nube.borrar("incidencias", "activo_id=in.(\(ids))")
            try await nube.borrar("trabajos", "activo_id=in.(\(ids))")
            try await nube.borrar("planes_mantenimiento", "activo_id=in.(\(ids))")
            for id in arbol(a.id).reversed() { try await nube.borrar("activos", "id=eq.\(id)") }
        }
    }

    func guardar(_ p: PlanMantenimiento) async {
        await intentar("Mantenimiento guardado") {
            var f = p.fila
            f["empresa_id"] = empresaId
            try await nube.insertar("planes_mantenimiento", f, upsert: true)
        }
    }

    func borrar(plan p: PlanMantenimiento) async {
        await intentar("Mantenimiento borrado") {
            try await nube.borrar("trabajos", "plan_id=eq.\(p.id)&estado=in.(0,1)")
            try await nube.borrar("planes_mantenimiento", "id=eq.\(p.id)")
        }
    }

    func pausar(_ p: PlanMantenimiento, _ pausado: Bool) async {
        await intentar { try await nube.actualizar("planes_mantenimiento", id: p.id, ["activa": !pausado]) }
    }

    // MARK: Oficina: órdenes

    func guardar(_ t: OrdenTrabajo, tecnicos ids: [String]? = nil) async {
        await intentar("Cambios guardados") {
            var f = t.fila
            f["empresa_id"] = empresaId
            try await nube.insertar("trabajos", f, upsert: true)
            if let ids { try await escribirAsignacion(t.id, ids) }
        }
    }

    func asignar(_ t: OrdenTrabajo, a ids: [String]) async {
        await intentar { try await escribirAsignacion(t.id, ids) }
    }

    private func escribirAsignacion(_ ot: String, _ ids: [String]) async throws {
        try await nube.borrar("trabajo_trabajadores", "trabajo_id=eq.\(ot)")
        for w in ids {
            try await nube.insertar("trabajo_trabajadores", ["trabajo_id": ot, "trabajador_id": w, "empresa_id": empresaId])
        }
    }

    func cambiarEstado(_ t: OrdenTrabajo, _ e: EstadoOT) async {
        await intentar(e == .cancelada ? "Orden cancelada" : "Cambios guardados") {
            try await nube.actualizar("trabajos", id: t.id, ["estado": e.rawValue])
        }
    }

    func borrar(ot t: OrdenTrabajo) async {
        await intentar("Orden borrada") { try await nube.borrar("trabajos", "id=eq.\(t.id)") }
    }

    // MARK: Oficina: incidencias

    func guardar(_ i: Incidencia) async {
        await intentar("Incidencia guardada") {
            try await nube.insertar("incidencias", [
                "id": i.id, "empresa_id": empresaId, "activo_id": i.activoId, "descripcion": i.descripcion,
                "gravedad": i.gravedad.rawValue, "estado": i.estado.rawValue,
                "plan_id": i.planId as Any? ?? NSNull(), "trabajo_id": i.trabajoId as Any? ?? NSNull(),
            ], upsert: true)
        }
    }

    /// Crea la OT correctiva de la incidencia y la enlaza al momento. Devuelve la OT creada.
    @discardableResult
    func crearOT(para i: Incidencia, interrumpiendo origen: OrdenTrabajo? = nil) async -> OrdenTrabajo? {
        var t = OrdenTrabajo.nueva(activo: i.activoId)
        t.nombre = String(localized: "Reparar \(activo(i.activoId)?.nombre ?? "")")
        t.descripcion = i.descripcion
        t.criticidad = i.gravedad.criticidad
        t.inicioMin = 480
        let tecnicosOT = origen?.tecnicoIds ?? orden(i.origenTrabajoId)?.tecnicoIds ?? [i.tecnicoId].compactMap { $0 }
        do {
            if let origen { try await nube.actualizar("trabajos", id: origen.id, ["estado": EstadoOT.interrumpida.rawValue]) }
            var f = t.fila
            f["empresa_id"] = empresaId
            try await nube.insertar("trabajos", f)
            try await escribirAsignacion(t.id, tecnicosOT)
            try await nube.actualizar("incidencias", id: i.id, ["trabajo_id": t.id, "estado": EstadoIncidencia.conOt.rawValue])
            try await cargar()
            avisar(String(localized: "Orden de trabajo creada"))
            return orden(t.id)
        } catch {
            avisar(error.localizedDescription, error: true)
            return nil
        }
    }

    /// Se resuelve dentro de la OT en la que se avisó: el técnico la reanuda.
    func seguirEnLaOT(_ i: Incidencia) async {
        guard let o = i.origenTrabajoId else { return }
        await intentar("El técnico puede seguir") {
            try await nube.actualizar("incidencias", id: i.id, ["trabajo_id": o, "estado": EstadoIncidencia.conOt.rawValue])
        }
    }

    func desestimar(_ i: Incidencia) async {
        await intentar("Incidencia desestimada") {
            try await nube.actualizar("incidencias", id: i.id,
                                      ["estado": EstadoIncidencia.desestimada.rawValue, "cerrada_el": Fechas.iso(Date())])
        }
    }

    func reabrir(_ i: Incidencia) async {
        await intentar("Incidencia reabierta") {
            try await nube.actualizar("incidencias", id: i.id, ["estado": EstadoIncidencia.abierta.rawValue, "cerrada_el": NSNull()])
        }
    }

    func cancelarOTyDesestimar(_ i: Incidencia) async {
        await intentar("Incidencia desestimada") {
            if let ot = orden(i.trabajoId), ot.estado.abierta {
                try await nube.actualizar("trabajos", id: ot.id, ["estado": EstadoOT.cancelada.rawValue])
            }
            try await nube.actualizar("incidencias", id: i.id,
                                      ["estado": EstadoIncidencia.desestimada.rawValue, "cerrada_el": Fechas.iso(Date())])
        }
    }

    // MARK: Oficina: técnicos y grupos

    func guardar(_ w: Tecnico) async {
        await intentar("Técnico guardado") {
            var f = w.fila
            f["empresa_id"] = empresaId
            try await nube.insertar("trabajadores", f, upsert: true)
        }
    }

    func guardarGrupo(id: String, nombre: String, miembros: Set<String>) async {
        await intentar("Grupo guardado") {
            try await nube.insertar("grupos", ["id": id, "nombre": nombre, "empresa_id": empresaId], upsert: true)
            for w in tecnicos {
                let dentro = miembros.contains(w.id), estaba = w.grupoIds.contains(id)
                guard dentro != estaba else { continue }
                let nuevos = dentro ? w.grupoIds + [id] : w.grupoIds.filter { $0 != id }
                try await nube.actualizar("trabajadores", id: w.id, ["grupo_ids": nuevos])
            }
        }
    }

    func borrarGrupo(_ g: Grupo) async {
        await intentar("Grupo borrado") {
            for w in tecnicos where w.grupoIds.contains(g.id) {
                try await nube.actualizar("trabajadores", id: w.id, ["grupo_ids": w.grupoIds.filter { $0 != g.id }])
            }
            try await nube.borrar("grupos", "id=eq.\(g.id)")
        }
    }

    func cambiarEstadoHoy(_ w: Tecnico, _ e: EstadoHoy) async {
        await intentar { try await nube.actualizar("trabajadores", id: w.id, ["estado_hoy": e.rawValue]) }
    }

    /// Enlace de invitación de 7 días para que el técnico entre con su cuenta (un solo uso).
    func invitar(_ w: Tecnico) async -> URL? {
        do {
            let r = try await nube.insertar("invitaciones", ["empresa_id": empresaId, "rol": "trabajador", "trabajador_id": w.id])
            guard let codigo = r.first?["codigo"] as? String else { return nil }
            return URL(string: "\(Configuracion.web)?invitacion=\(codigo)")
        } catch {
            avisar(error.localizedDescription, error: true)
            return nil
        }
    }

    // MARK: Ajustes

    struct AvisoCorreo: Identifiable, Hashable { let id: String; let evento: String; let correo: String; var activa: Bool }

    func avisosCorreo() async -> [AvisoCorreo] {
        let r = (try? await nube.filas("avisos_correo", "select=id,evento,correo,activa&empresa_id=eq.\(empresaId)&order=created_at")) ?? []
        return r.map { AvisoCorreo(id: $0["id"] as? String ?? "", evento: $0["evento"] as? String ?? "",
                                   correo: $0["correo"] as? String ?? "", activa: $0["activa"] as? Bool ?? true) }
    }

    func crearAvisoCorreo(_ evento: String, _ correo: String) async {
        await intentar { try await nube.insertar("avisos_correo", ["empresa_id": empresaId, "evento": evento,
                                                                   "correo": correo.trimmingCharacters(in: .whitespaces).lowercased()]) }
    }

    func borrarAvisoCorreo(_ id: String) async {
        await intentar { try await nube.borrar("avisos_correo", "id=eq.\(id)") }
    }

    /// Plan de la empresa: («Premium», «Activo», fin del periodo) o Básico.
    func planEmpresa() async -> (nombre: String, estado: String?, fin: Date?) {
        let r = try? await nube.filas("suscripciones", "select=plan,estado,fin_periodo&empresa_id=eq.\(empresaId)")
        guard let x = r?.first, (x["plan"] as? String) == "premium" else { return ("Básico", nil, nil) }
        return ("Premium", x["estado"] as? String, Fechas.instante(x["fin_periodo"]))
    }

    func renombrarEmpresa(_ nombre: String) async {
        await intentar("Cambios guardados") {
            try await nube.actualizar("empresas", id: empresaId, ["nombre": nombre])
            empresaNombre = nombre
        }
    }

    // MARK: Técnico

    /// El técnico de la vista de técnico: la cuenta de técnico o el elegido por la oficina.
    var tecnicoActivo: String? { viendoComo ?? (esAdmin ? nil : miTecnicoId) }

    func misOrdenes(_ w: String) -> [OrdenTrabajo] {
        let elegidos = Set(tecnico(w)?.activosElegidos ?? [])
        return pendientes.filter {
            $0.tecnicoIds.contains(w) && (elegidos.isEmpty || elegidos.contains(raiz($0.activoId)?.id ?? ""))
        }
    }

    func guardarMiPerfil(telefono: String) async {
        await intentar("Cambios guardados") {
            try await nube.rpc("guardar_mi_perfil", ["p_empresa": empresaId, "p_foto": "", "p_telefono": telefono])
        }
    }

    func guardarActivosElegidos(_ w: String, _ ids: [String]) async {
        await intentar { try await nube.rpc("guardar_activos_elegidos", ["p_trabajador": w, "p_activos": ids]) }
    }

    func empezar(_ t: OrdenTrabajo) async {
        await intentar("Orden empezada") {
            if viendoComo != nil {
                // La oficina viendo la app como un técnico: `tomar_ot` es solo para cuentas de técnico;
                // como la web, se empieza escribiendo la OT.
                var cambios: [String: Any] = ["estado": EstadoOT.enCurso.rawValue]
                if t.iniciadaEn == nil { cambios["iniciada_en"] = Fechas.iso(Date()) }
                try await nube.actualizar("trabajos", id: t.id, cambios)
            } else {
                try await nube.rpc("tomar_ot", ["p_trabajo": t.id])
            }
        }
    }

    func pausar(_ t: OrdenTrabajo, _ pausar: Bool) async {
        await intentar(pausar ? "Orden pausada" : "Orden reanudada") {
            try await nube.rpc("pausar_ot", ["p_trabajo": t.id, "p_pausar": pausar])
        }
    }

    func marcarChecklist(_ t: OrdenTrabajo, _ pasos: [PasoChecklist]) async {
        await intentar { try await nube.rpc("marcar_checklist", ["p_trabajo": t.id, "p_checklist": pasos.map(\.json)]) }
    }

    /// Minutos trabajados desde «Empezar OT», sin las pausas.
    func minutos(_ t: OrdenTrabajo) -> Int? {
        guard let inicio = t.iniciadaEn else { return nil }
        let fin = t.pausadaDesde ?? Date()
        return max(0, Int(fin.timeIntervalSince(inicio)) - t.segundosPausa) / 60
    }

    func crearIncidencia(_ i: Incidencia, fotos: [Data]) async -> Bool {
        do {
            var rutas: [String] = []
            for (n, f) in fotos.enumerated() {
                let ruta = "\(empresaId)/incidencias/\(i.id)/\(n).jpg"
                try await nube.subir(ruta, f, tipo: "image/jpeg")
                rutas.append(ruta)
            }
            try await nube.rpc("crear_incidencia", [
                "p_id": i.id, "p_activo": i.activoId, "p_descripcion": i.descripcion,
                "p_gravedad": i.gravedad.rawValue, "p_categoria": "", "p_fotos": rutas,
                "p_tecnico": i.tecnicoId as Any? ?? NSNull(), "p_origen": i.origenTrabajoId as Any? ?? NSNull(),
            ])
            try? await cargar()
            avisar(String(localized: "Incidencia enviada"))
            return true
        } catch {
            avisar(error.localizedDescription, error: true)
            return false
        }
    }

    func editarIncidencia(_ i: Incidencia) async {
        await intentar("Cambios enviados") {
            try await nube.rpc("editar_incidencia", [
                "p_id": i.id, "p_activo": i.activoId, "p_descripcion": i.descripcion,
                "p_gravedad": i.gravedad.rawValue, "p_origen": i.origenTrabajoId as Any? ?? NSNull(), "p_fotos": i.fotos,
            ])
        }
    }

    /// Parte del técnico: sube fotos y firma, guarda el informe, apunta el contador y cierra la OT
    /// (salvo «No se pudo hacer», que deja la OT abierta: la base abre la incidencia).
    func cerrar(_ t: OrdenTrabajo, tecnico w: String?, resultado: Resultado, notas: String, material: String,
                contador: Double?, valor: Double?, fotos: [Data], firma: Data?) async -> Bool {
        let id = UUID().uuidString.lowercased()
        do {
            var rutas: [String] = []
            for (n, f) in fotos.enumerated() {
                let ruta = "\(empresaId)/informes/\(id)/\(n).jpg"
                try await nube.subir(ruta, f, tipo: "image/jpeg")
                rutas.append(ruta)
            }
            var rutaFirma: Any = NSNull()
            if let firma {
                let ruta = "\(empresaId)/informes/\(id)/firma.png"
                try await nube.subir(ruta, firma, tipo: "image/png")
                rutaFirma = ruta
            }
            var informe: [String: Any] = [
                "id": id, "empresa_id": empresaId, "trabajo_id": t.id, "trabajador_id": w as Any? ?? NSNull(),
                "resultado": resultado.rawValue, "notas": notas, "material": material,
                "minutos": minutos(t) as Any? ?? NSNull(), "fotos": rutas, "firma": rutaFirma, "firmante": "",
                "created_at": Fechas.iso(Date()),
            ]
            if let valor { informe["valor"] = valor }
            try await nube.insertar("informes", informe)
            if let contador, let r = raiz(t.activoId) {
                try? await nube.rpc("apuntar_contador", ["p_activo": r.id, "p_horas": contador])
            }
            if resultado != .noSePudo {
                try await nube.actualizar("trabajos", id: t.id, [
                    "estado": EstadoOT.completada.rawValue, "ultimo": Fechas.texto(Fechas.hoy), "proximo": NSNull(),
                ])
            }
            try? await cargar()
            avisar(String(localized: resultado == .noSePudo ? "Parte enviado" : "Orden cerrada y parte enviado"))
            return true
        } catch {
            avisar(error.localizedDescription, error: true)
            return false
        }
    }

    func informes(de ot: String) async -> [Informe] {
        (try? await nube.filas("informes", "select=*&trabajo_id=eq.\(ot)&order=created_at.desc"))?.map(Informe.init) ?? []
    }

    func informes(deTecnico w: String) async -> [Informe] {
        (try? await nube.filas("informes", "select=*&empresa_id=eq.\(empresaId)&trabajador_id=eq.\(w)&order=created_at.desc"))?
            .map(Informe.init) ?? []
    }

    func foto(_ ruta: String) async -> Data? {
        if let d = cacheFotos[ruta] { return d }
        let d = try? await nube.descargar(ruta)
        cacheFotos[ruta] = d
        return d
    }

    private var cacheFotos: [String: Data] = [:]
}
