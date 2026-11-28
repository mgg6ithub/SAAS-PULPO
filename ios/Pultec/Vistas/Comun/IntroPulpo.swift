import SwiftUI

/// Entrada al abrir la app, la misma de la landing y de la web (`app/lib/intro_pulpo.dart`): todo en blanco, el
/// pulpo cae grande en el centro, saca los tentáculos, parpadea y vuela arriba a la izquierda mientras el blanco
/// se desvanece. Un toque la salta; con «Reducir movimiento» no sale. Misma geometría (SVG de la landing,
/// viewBox 126 136 772 758) y mismos tiempos (2,81 s).
struct IntroPulpo: View {
    let alTerminar: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reducir
    @Environment(\.colorScheme) private var esquema
    @State private var inicio = Date()
    @State private var terminado = false

    private static let total = 2.81

    var body: some View {
        GeometryReader { g in
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSince(inicio) * 1000
                Canvas { ctx, size in
                    PintorPulpo.pintar(&ctx, size: size, t: t, arriba: g.safeAreaInsets.top,
                                       fondo: esquema == .dark ? Color(hex: 0x1C1B24) : .white)
                }
                .onChange(of: t >= Self.total * 1000) { _, fin in if fin { terminar() } }
            }
        }
        .ignoresSafeArea()
        .contentShape(.rect)
        .onTapGesture { terminar() }
        .onAppear {
            inicio = Date()
            if reducir { terminar() }
        }
        .accessibilityHidden(true)
    }

    private func terminar() {
        guard !terminado else { return }
        terminado = true
        alTerminar()
    }
}

/// Dibujo del pulpo en cada fotograma.
private enum PintorPulpo {
    static let caja = CGRect(x: 126, y: 136, width: 772, height: 758)

    static let cabeza: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 512, y: 160))
        p.addCurve(to: CGPoint(x: 708, y: 360), control1: CGPoint(x: 628, y: 160), control2: CGPoint(x: 708, y: 245))
        p.addCurve(to: CGPoint(x: 605, y: 570), control1: CGPoint(x: 708, y: 450), control2: CGPoint(x: 655, y: 505))
        p.addCurve(to: CGPoint(x: 419, y: 570), control1: CGPoint(x: 575, y: 598), control2: CGPoint(x: 449, y: 598))
        p.addCurve(to: CGPoint(x: 316, y: 360), control1: CGPoint(x: 369, y: 505), control2: CGPoint(x: 316, y: 450))
        p.addCurve(to: CGPoint(x: 512, y: 160), control1: CGPoint(x: 316, y: 245), control2: CGPoint(x: 396, y: 160))
        p.closeSubpath()
        return p
    }()

    /// Seis tentáculos de siete puntos (dos curvas). Los tres primeros, a la izquierda.
    static let tentaculos: [[CGPoint]] = [
        [(352, 452), (300, 500), (230, 500), (205, 450), (185, 405), (215, 365), (255, 380)],
        [(400, 545), (330, 600), (240, 590), (190, 625), (140, 662), (160, 725), (210, 715)],
        [(465, 575), (455, 660), (385, 700), (370, 770), (358, 830), (415, 860), (445, 820)],
        [(672, 452), (724, 500), (794, 500), (819, 450), (839, 405), (809, 365), (769, 380)],
        [(624, 545), (694, 600), (784, 590), (834, 625), (884, 662), (864, 725), (814, 715)],
        [(559, 575), (569, 660), (639, 700), (654, 770), (666, 830), (609, 860), (579, 820)],
    ].map { $0.map { CGPoint(x: $0.0, y: $0.1) } }

    /// Salen de dentro hacia fuera, alternando lados; cada uno con su ritmo, fuerza y desfase.
    static let orden = [0, 3, 1, 4, 2, 5]
    static let gestos: [(f: Double, fase: Double, amp: Double, k: Double, cie: Double)] = [
        (7.4, 0.0, 1.0, 4.2, 1.0), (9.0, 2.3, 0.65, 3.4, 0.6), (6.3, 4.1, 1.15, 5.0, 0.85),
        (8.2, 1.2, 0.8, 3.8, 1.15), (6.9, 3.4, 1.05, 4.6, 0.7), (8.7, 5.2, 0.7, 3.6, 1.05),
    ]

    /// Avance a lo largo de cada tentáculo (0 en la base, 1 en la punta), por la cuerda entre sus puntos.
    static let pesos: [[Double]] = tentaculos.map { pts in
        var acum: [Double] = [0]
        for i in 1..<pts.count { acum.append(acum.last! + hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)) }
        return acum.map { $0 / acum.last! }
    }

    static let rebote = Bezier(0.2, 0.8, 0.2, 1)
    static let salida = Bezier(0, 0, 0.58, 1)
    static let vaiven = Bezier(0.42, 0, 0.58, 1)
    static let viaje = Bezier(0.65, 0, 0.25, 1)

    static func suave(_ x: Double) -> Double { x <= 0 ? 0 : (x >= 1 ? 1 : x * x * (3 - 2 * x)) }
    static func tramo(_ t: Double, _ a: Double, _ dur: Double) -> Double { min(1, max(0, (t - a) / dur)) }
    static func lerp(_ a: Double, _ b: Double, _ p: Double) -> Double { a + (b - a) * p }

    /// Interpola fotogramas [(offset, valores…)] en p, lineal entre ellos.
    static func fotogramas(_ kf: [[Double]], _ p: Double) -> [Double] {
        for i in 1..<kf.count where p <= kf[i][0] || i == kf.count - 1 {
            let a = kf[i - 1], b = kf[i]
            let q = min(1, max(0, (p - a[0]) / (b[0] - a[0])))
            return (1..<a.count).map { lerp(a[$0], b[$0], q) }
        }
        return Array(kf.last!.dropFirst())
    }

    static func pintar(_ ctx: inout GraphicsContext, size: CGSize, t: Double, arriba: CGFloat, fondo: Color) {
        // Fondo: se desvanece durante el vuelo.
        let alfa = 1 - salida.y(tramo(t, 2300, 500))
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(fondo.opacity(alfa)))

        let ancho = min(260, size.width * 0.52)
        let k = ancho / caja.width
        let alto = caja.height * k
        let centro = CGPoint(x: size.width / 2, y: size.height / 2)

        // 4. Vuelo arriba a la izquierda (donde va el título de cada pantalla).
        var tx = 0.0, ty = 0.0, s = 1.0
        if t >= 2050 {
            let d = CGRect(x: 16, y: arriba + 6, width: 34, height: 34)
            let dx = d.midX - centro.x, dy = d.midY - centro.y
            let v = fotogramas([[0, 0, 0, 1], [0.2, dx * 0.15, dy * 0.05 - 20, 1.05], [1, dx, dy, d.width * 0.92 / ancho]],
                               viaje.y(tramo(t, 2050, 750)))
            tx = v[0]; ty = v[1]; s = v[2]
        }

        var c = ctx
        c.translateBy(x: centro.x + tx, y: centro.y + ty)
        c.scaleBy(x: s, y: s)
        c.translateBy(x: -ancho / 2, y: -alto / 2)
        c.scaleBy(x: k, y: k)
        c.translateBy(x: -caja.minX, y: -caja.minY)

        let degradado = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [Color(hex: 0x9C6CFF), Color(hex: 0x4A10C8)]),
            startPoint: CGPoint(x: 512, y: 160), endPoint: CGPoint(x: 512, y: 870))

        // 2. Tentáculos: salen uno a uno y se doblan como en el agua hasta su forma.
        let estilo = StrokeStyle(lineWidth: 78, lineCap: .round)
        for (n, i) in orden.enumerated() {
            let retraso = 450 + Double(n) * 90
            let dibujado = rebote.y(tramo(t, retraso, 650))
            guard dibujado > 0 else { continue }
            let pts = tentaculos[i]
            let ms = t - retraso
            var q = pts
            if ms < 2000 {
                let g = gestos[n]
                let lado: Double = i < 3 ? -1 : 1
                let seg = max(0, ms) / 1000
                let cierre = lado * -0.22 * g.cie * (1 - suave(ms / 1100))
                let amp = 0.12 * g.amp * suave(ms / 250) * (1 - suave((ms - 300) / 1700))
                let base = pts[0]
                q = pts.enumerated().map { j, p in
                    let w = pesos[i][j]
                    let ang = w * (cierre + amp * sin(seg * g.f - w * g.k + g.fase))
                    let dx = p.x - base.x, dy = p.y - base.y
                    return CGPoint(x: base.x + dx * cos(ang) - dy * sin(ang), y: base.y + dx * sin(ang) + dy * cos(ang))
                }
            }
            var camino = Path()
            camino.move(to: q[0])
            camino.addCurve(to: q[3], control1: q[1], control2: q[2])
            camino.addCurve(to: q[6], control1: q[4], control2: q[5])
            c.stroke(dibujado >= 1 ? camino : camino.trimmedPath(from: 0, to: dibujado), with: degradado, style: estilo)
        }

        // 1. La cabeza cae y rebota (estira y aplasta), con origen abajo en el centro.
        let cab = fotogramas([[0, 0, -120, 0.6, 0.9], [0.55, 1, 0, 1.12, 0.86], [0.8, 1, -14, 0.95, 1.06], [1, 1, 0, 1, 1]],
                             salida.y(tramo(t, 0, 700)))
        guard cab[0] > 0 else { return }
        var h = c
        h.translateBy(x: 512, y: 591 + cab[1])
        h.scaleBy(x: cab[2], y: cab[3])
        h.translateBy(x: -512, y: -591)
        h.drawLayer { capa in
            capa.opacity = cab[0]
            capa.fill(cabeza, with: degradado)
            // 3. Parpadeo.
            let ojo = fotogramas([[0, 1], [0.5, 0.1], [1, 1]], vaiven.y(tramo(t, 1450, 220)))[0]
            for x in [452.0, 572.0] {
                capa.fill(Path(ellipseIn: CGRect(x: x - 32, y: 410 - 32 * ojo, width: 64, height: 64 * ojo)), with: .color(.white))
            }
        }
    }
}

/// Curva de Bézier cúbica de easing (como `Cubic` de Flutter / `cubic-bezier` de CSS).
struct Bezier {
    let x1, y1, x2, y2: Double
    init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) { self.x1 = x1; self.y1 = y1; self.x2 = x2; self.y2 = y2 }

    private func punto(_ a: Double, _ b: Double, _ m: Double) -> Double {
        3 * a * (1 - m) * (1 - m) * m + 3 * b * (1 - m) * m * m + m * m * m
    }

    func y(_ x: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        var lo = 0.0, hi = 1.0
        for _ in 0..<24 {
            let m = (lo + hi) / 2
            if punto(x1, x2, m) < x { lo = m } else { hi = m }
        }
        return punto(y1, y2, (lo + hi) / 2)
    }
}
