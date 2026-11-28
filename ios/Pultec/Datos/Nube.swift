import Foundation

/// Dónde está la Supabase de Pultec. Se desarrolla siempre contra la local
/// (`./entorno.sh arrancar`); producción solo con la skill `subir-a-produccion`.
enum Configuracion {
    static let url = URL(string: "http://127.0.0.1:54321")!
    static let clave = "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"
    static let marca = "industrial"
    static let bucketFotos = "fotos"
    /// Web de Pultec (enlaces de invitación). En local, la app web de `./entorno.sh app`.
    static let web = "http://localhost:8000/"
}

struct ErrorNube: LocalizedError {
    let mensaje: String
    var errorDescription: String? { mensaje }
}

/// Sesión guardada (en Llavero sería lo ideal; por ahora UserDefaults en desarrollo).
struct Sesion: Codable {
    var accessToken: String
    var refreshToken: String
    var caduca: Date
    var usuarioId: String
    var correo: String
}

/// Cliente mínimo de Supabase sobre URLSession: Auth (GoTrue), PostgREST, RPC y Storage.
/// Mismo contrato que la app web (`app/lib/nube.dart`): mismas tablas, RLS y funciones.
actor Nube {
    static let compartida = Nube()

    private(set) var sesion: Sesion?
    private let decoder = JSONDecoder()
    private let claveSesion = "pultec.sesion"

    init() {
        // Antes se guardaba en UserDefaults: se pasa al Llavero una vez.
        if let viejo = UserDefaults.standard.data(forKey: claveSesion) {
            Llavero.guardar(viejo, claveSesion)
            UserDefaults.standard.removeObject(forKey: claveSesion)
        }
        if let d = Llavero.leer(claveSesion), let s = try? JSONDecoder().decode(Sesion.self, from: d) {
            sesion = s
        }
    }

    var token: String? { sesion?.accessToken }

    var usuarioId: String? { sesion?.usuarioId }
    var correo: String? { sesion?.correo }

    // MARK: Auth

    func entrar(correo: String, contrasena: String) async throws {
        let cuerpo = ["email": correo, "password": contrasena]
        let datos = try await peticion("POST", "/auth/v1/token?grant_type=password", cuerpo: cuerpo, conSesion: false)
        try guardarSesion(datos)
    }

    func registrarse(correo: String, contrasena: String) async throws {
        let cuerpo = ["email": correo, "password": contrasena]
        let datos = try await peticion("POST", "/auth/v1/signup", cuerpo: cuerpo, conSesion: false)
        if (try? JSONSerialization.jsonObject(with: datos) as? [String: Any])?["access_token"] != nil {
            try guardarSesion(datos)
        } else {
            try await entrar(correo: correo, contrasena: contrasena)
        }
    }

    func recuperar(correo: String) async throws {
        _ = try await peticion("POST", "/auth/v1/recover", cuerpo: ["email": correo], conSesion: false)
    }

    func salir() {
        sesion = nil
        Llavero.borrar(claveSesion)
    }

    private func guardarSesion(_ datos: Data) throws {
        guard let j = try JSONSerialization.jsonObject(with: datos) as? [String: Any],
              let token = j["access_token"] as? String,
              let refresh = j["refresh_token"] as? String,
              let usuario = j["user"] as? [String: Any],
              let id = usuario["id"] as? String else {
            throw ErrorNube(mensaje: "No se pudo iniciar sesión.")
        }
        let segundos = (j["expires_in"] as? Double) ?? 3600
        let s = Sesion(accessToken: token, refreshToken: refresh,
                       caduca: Date().addingTimeInterval(segundos - 60),
                       usuarioId: id, correo: usuario["email"] as? String ?? "")
        sesion = s
        Llavero.guardar(try JSONEncoder().encode(s), claveSesion)
    }

    /// Entrar con Google o Apple (OAuth de Supabase): la web de Supabase vuelve a `pultec://auth#access_token=…`.
    static func urlOAuth(_ proveedor: String) -> URL {
        var c = URLComponents(url: Configuracion.url.appendingPathComponent("auth/v1/authorize"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "provider", value: proveedor), URLQueryItem(name: "redirect_to", value: "pultec://auth")]
        return c.url!
    }

    /// Guarda la sesión que trae la vuelta del OAuth (fragmento con access_token y refresh_token).
    func entrarConVuelta(_ url: URL) async throws {
        let texto = url.fragment ?? url.query ?? ""
        var p: [String: String] = [:]
        for par in texto.split(separator: "&") {
            let kv = par.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2 { p[kv[0]] = kv[1].removingPercentEncoding ?? kv[1] }
        }
        if let e = p["error_description"] { throw ErrorNube(mensaje: e.replacingOccurrences(of: "+", with: " ")) }
        guard let token = p["access_token"], let refresh = p["refresh_token"] else {
            throw ErrorNube(mensaje: "No se pudo iniciar sesión.")
        }
        var r = try await solicitud("GET", "/auth/v1/user", conSesion: false)
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (datos, respuesta) = try await URLSession.shared.data(for: r)
        try comprobar(respuesta, datos)
        let usuario = (try JSONSerialization.jsonObject(with: datos) as? [String: Any]) ?? [:]
        let j: [String: Any] = ["access_token": token, "refresh_token": refresh,
                                "expires_in": Double(p["expires_in"] ?? "3600") ?? 3600, "user": usuario]
        try guardarSesion(try JSONSerialization.data(withJSONObject: j))
    }

    private func refrescarSiHaceFalta() async throws {
        guard let s = sesion, s.caduca < Date() else { return }
        let datos = try await peticion("POST", "/auth/v1/token?grant_type=refresh_token",
                                       cuerpo: ["refresh_token": s.refreshToken], conSesion: false)
        try guardarSesion(datos)
    }

    // MARK: PostgREST

    /// Filas de una tabla. `consulta` en formato PostgREST: `select=*&empresa_id=eq.X`.
    func filas(_ tabla: String, _ consulta: String) async throws -> [[String: Any]] {
        var todas: [[String: Any]] = []
        var desde = 0
        while true {
            let datos = try await peticion("GET", "/rest/v1/\(tabla)?\(consulta)",
                                           cabeceras: ["Range": "\(desde)-\(desde + 999)", "Range-Unit": "items"])
            let lote = (try JSONSerialization.jsonObject(with: datos) as? [[String: Any]]) ?? []
            todas += lote
            if lote.count < 1000 { return todas }
            desde += 1000
        }
    }

    @discardableResult
    func insertar(_ tabla: String, _ fila: [String: Any], upsert: Bool = false) async throws -> [[String: Any]] {
        var preferir = "return=representation"
        if upsert { preferir += ",resolution=merge-duplicates" }
        let datos = try await peticion("POST", "/rest/v1/\(tabla)", cuerpo: fila, cabeceras: ["Prefer": preferir])
        return (try JSONSerialization.jsonObject(with: datos) as? [[String: Any]]) ?? []
    }

    func actualizar(_ tabla: String, id: String, _ cambios: [String: Any]) async throws {
        _ = try await peticion("PATCH", "/rest/v1/\(tabla)?id=eq.\(id)", cuerpo: cambios,
                               cabeceras: ["Prefer": "return=minimal"])
    }

    func borrar(_ tabla: String, _ filtro: String) async throws {
        _ = try await peticion("DELETE", "/rest/v1/\(tabla)?\(filtro)", cabeceras: ["Prefer": "return=minimal"])
    }

    @discardableResult
    func rpc(_ funcion: String, _ parametros: [String: Any] = [:]) async throws -> Any? {
        let datos = try await peticion("POST", "/rest/v1/rpc/\(funcion)", cuerpo: parametros)
        guard !datos.isEmpty else { return nil }
        return try? JSONSerialization.jsonObject(with: datos, options: [.fragmentsAllowed])
    }

    // MARK: Storage

    func subir(_ ruta: String, _ bytes: Data, tipo: String) async throws {
        var r = try await solicitud("POST", "/storage/v1/object/\(Configuracion.bucketFotos)/\(ruta)")
        r.setValue(tipo, forHTTPHeaderField: "Content-Type")
        r.setValue("true", forHTTPHeaderField: "x-upsert")
        r.httpBody = bytes
        let (datos, respuesta) = try await URLSession.shared.data(for: r)
        try comprobar(respuesta, datos)
    }

    func descargar(_ ruta: String) async throws -> Data {
        let r = try await solicitud("GET", "/storage/v1/object/\(Configuracion.bucketFotos)/\(ruta)")
        let (datos, respuesta) = try await URLSession.shared.data(for: r)
        try comprobar(respuesta, datos)
        return datos
    }

    // MARK: Peticiones

    private func solicitud(_ metodo: String, _ ruta: String, conSesion: Bool = true) async throws -> URLRequest {
        if conSesion { try await refrescarSiHaceFalta() }
        guard let url = URL(string: Configuracion.url.absoluteString + ruta) else {
            throw ErrorNube(mensaje: "Dirección no válida.")
        }
        var r = URLRequest(url: url)
        r.httpMethod = metodo
        r.timeoutInterval = 30
        r.setValue(Configuracion.clave, forHTTPHeaderField: "apikey")
        let token = conSesion ? (sesion?.accessToken ?? Configuracion.clave) : Configuracion.clave
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return r
    }

    private func peticion(_ metodo: String, _ ruta: String, cuerpo: Any? = nil,
                          cabeceras: [String: String] = [:], conSesion: Bool = true) async throws -> Data {
        var r = try await solicitud(metodo, ruta, conSesion: conSesion)
        for (k, v) in cabeceras { r.setValue(v, forHTTPHeaderField: k) }
        if let cuerpo {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try JSONSerialization.data(withJSONObject: cuerpo)
        }
        let (datos, respuesta) = try await URLSession.shared.data(for: r)
        try comprobar(respuesta, datos)
        return datos
    }

    private func comprobar(_ respuesta: URLResponse, _ datos: Data) throws {
        guard let http = respuesta as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let j = try? JSONSerialization.jsonObject(with: datos) as? [String: Any]
            let texto = (j?["msg"] ?? j?["message"] ?? j?["error_description"] ?? j?["error"]) as? String
            if http.statusCode == 400, ruta400EsLogin(texto) {
                throw ErrorNube(mensaje: "Correo o contraseña incorrectos.")
            }
            throw ErrorNube(mensaje: texto ?? "Error \(http.statusCode) del servidor.")
        }
    }

    private func ruta400EsLogin(_ texto: String?) -> Bool {
        (texto ?? "").localizedCaseInsensitiveContains("invalid login")
    }
}
