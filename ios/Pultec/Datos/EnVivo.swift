import Foundation

/// Cambios en vivo con Supabase Realtime (protocolo Phoenix sobre WebSocket), como `app/lib/en_vivo.dart`:
/// escucha las tablas de la empresa y avisa una sola vez por ráfaga para recargar.
final class EnVivo: NSObject, @unchecked Sendable {
    static let tablas = ["activos", "planes_mantenimiento", "trabajos", "trabajo_trabajadores", "incidencias",
                         "trabajadores", "grupos", "informes"]

    private let empresaId: String
    private let token: String
    private let alCambiar: @Sendable () -> Void
    private var tarea: URLSessionWebSocketTask?
    private var latido: Timer?
    private var rafaga: Timer?
    private var ref = 0
    private var parado = false

    init(empresaId: String, token: String, alCambiar: @escaping @Sendable () -> Void) {
        self.empresaId = empresaId
        self.token = token
        self.alCambiar = alCambiar
    }

    func empezar() {
        var c = URLComponents(url: Configuracion.url, resolvingAgainstBaseURL: false)!
        c.scheme = c.scheme == "https" ? "wss" : "ws"
        c.path = "/realtime/v1/websocket"
        c.queryItems = [URLQueryItem(name: "apikey", value: Configuracion.clave), URLQueryItem(name: "vsn", value: "1.0.0")]
        let t = URLSession.shared.webSocketTask(with: c.url!)
        tarea = t
        t.resume()
        unirse()
        escuchar()
        DispatchQueue.main.async {
            self.latido = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
                self?.enviar(topic: "phoenix", evento: "heartbeat", payload: [:])
            }
        }
    }

    func parar() {
        parado = true
        latido?.invalidate()
        rafaga?.invalidate()
        tarea?.cancel(with: .goingAway, reason: nil)
    }

    private func unirse() {
        var cambios: [[String: Any]] = []
        for t in Self.tablas {
            for e in ["INSERT", "UPDATE"] {
                cambios.append(["event": e, "schema": "public", "table": t, "filter": "empresa_id=eq.\(empresaId)"])
            }
            // Los borrados no se pueden filtrar (solo traen la clave): llegan todos.
            cambios.append(["event": "DELETE", "schema": "public", "table": t])
        }
        enviar(topic: "realtime:empresa:\(empresaId)", evento: "phx_join", payload: [
            "config": ["broadcast": ["self": false], "presence": ["key": ""], "postgres_changes": cambios],
            "access_token": token,
        ])
    }

    private func enviar(topic: String, evento: String, payload: [String: Any]) {
        ref += 1
        let m: [String: Any] = ["topic": topic, "event": evento, "payload": payload, "ref": "\(ref)"]
        guard let d = try? JSONSerialization.data(withJSONObject: m), let s = String(data: d, encoding: .utf8) else { return }
        tarea?.send(.string(s)) { _ in }
    }

    private func escuchar() {
        tarea?.receive { [weak self] r in
            guard let self, !self.parado else { return }
            switch r {
            case .success(let m):
                if case .string(let s) = m, s.contains("\"postgres_changes\"") { self.cambio() }
                self.escuchar()
            case .failure:
                // Se cortó: reintenta a los 5 s y recarga todo (no llegan los cambios de mientras).
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    guard let self, !self.parado else { return }
                    self.latido?.invalidate()
                    self.empezar()
                    self.alCambiar()
                }
            }
        }
    }

    private func cambio() {
        DispatchQueue.main.async {
            self.rafaga?.invalidate()
            self.rafaga = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in self?.alCambiar() }
        }
    }
}
