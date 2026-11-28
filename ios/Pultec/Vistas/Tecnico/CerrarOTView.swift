import SwiftUI
import PhotosUI
import PencilKit

/// Parte al cerrar la OT: resultado, qué has hecho, repuestos y contador, medición, fotos y firma.
struct CerrarOTView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var dismiss
    let ot: OrdenTrabajo
    let apuntes: String
    let alCerrar: () -> Void

    @State private var resultado: Resultado = .correcto
    @State private var notas = ""
    @State private var material = ""
    @State private var contador: Double?
    @State private var medida: Double?
    @State private var fotos: [Data] = []
    @State private var firma = PKCanvasView()
    @State private var hayFirma = false
    @State private var enviando = false
    @State private var incidencia = false

    private var raiz: Activo? { almacen.raiz(ot.activoId) }
    private var plan: PlanMantenimiento? { almacen.plan(ot.planId) }

    var body: some View {
        NavigationStack {
            Form {
                Section {} header: {
                    Picker("Resultado", selection: $resultado) {
                        ForEach(Resultado.allCases) { Text($0.etiqueta).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: resultado) { _, r in if r == .conIncidencias { incidencia = true } }
                }
                Section {
                    TextField("Ej.: revisado el motor, cambiada la correa. Falta pedir una pieza.", text: $notas, axis: .vertical).lineLimit(4...10)
                } header: { Text("Qué has hecho") } footer: { Text("Lo que has pasado, lo que has cambiado y lo que queda pendiente.") }
                Section {
                    TextField("Ej.: 1 correa, 2 l de aceite", text: $material, axis: .vertical).lineLimit(1...4)
                    if let raiz {
                        LabeledContent("Contador (h)") {
                            TextField("\(Int(raiz.horas))", value: $contador, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                    }
                } header: { Text("Repuestos y contador") } footer: {
                    if let raiz { Text("Las horas que marca ahora el contador de \(raiz.nombreCompleto).") }
                }
                if let plan, !plan.medicionNombre.isEmpty {
                    Section {
                        LabeledContent("\(plan.medicionNombre) (\(plan.medicionUnidad))") {
                            TextField("—", value: $medida, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                    } header: { Text("Medición") } footer: {
                        if let mn = plan.medicionMin, let mx = plan.medicionMax { Text("Entre \(mn.formatted()) y \(mx.formatted()). Si sale de ahí, se abre una incidencia sola.") }
                    }
                }
                Section {
                    SelectorFotos(fotos: $fotos)
                } header: { Text("Fotos") } footer: { Text("Del equipo, de la avería o de la orden terminada. Hasta 6.") }
                Section {
                    FirmaView(lienzo: $firma, hayFirma: $hayFirma).frame(height: 160)
                    if hayFirma {
                        Button("Borrar firma", role: .destructive) { firma.drawing = PKDrawing(); hayFirma = false }
                    }
                } header: { Text("Firma del responsable") } footer: { Text("Que firme con el dedo en el recuadro. Si no está, déjalo en blanco.") }
            }
            .fondoTema()
            .disabled(enviando)
            .overlay { if enviando { ProgressView("Enviando el parte…").padding(24).glassEffect(in: .rect(cornerRadius: 20)) } }
            .hojaFormulario(ot.nombre, puedeGuardar: !enviando, guardar: enviar)
            .onAppear {
                notas = apuntes
                contador = raiz?.horas
            }
            .sheet(isPresented: $incidencia) {
                CrearIncidenciaView(incidencia: .nueva(activo: ot.activoId ?? "", tecnico: almacen.tecnicoActivo, origen: ot.id))
            }
        }
        .interactiveDismissDisabled(enviando)
    }

    private func enviar() {
        enviando = true
        Task {
            let png: Data? = hayFirma ? firma.drawing.image(from: firma.bounds, scale: 2).pngData() : nil
            let ok = await almacen.cerrar(ot, tecnico: almacen.tecnicoActivo, resultado: resultado, notas: notas,
                                          material: material, contador: contador, valor: medida, fotos: fotos, firma: png)
            enviando = false
            if ok { alCerrar(); dismiss() }
        }
    }
}

/// Lienzo de firma (PencilKit: dedo o Apple Pencil).
struct FirmaView: UIViewRepresentable {
    @Binding var lienzo: PKCanvasView
    @Binding var hayFirma: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        lienzo.drawingPolicy = .anyInput
        lienzo.tool = PKInkingTool(.pen, color: .label, width: 3)
        lienzo.backgroundColor = .clear
        lienzo.delegate = context.coordinator
        return lienzo
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinador { Coordinador(self) }

    final class Coordinador: NSObject, PKCanvasViewDelegate {
        let padre: FirmaView
        init(_ padre: FirmaView) { self.padre = padre }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            padre.hayFirma = !canvasView.drawing.strokes.isEmpty
        }
    }
}

/// Hacer foto (cámara) o elegir de la fototeca; hasta 6, comprimidas a JPEG.
struct SelectorFotos: View {
    @Binding var fotos: [Data]
    var maximo = 6
    @State private var elegidas: [PhotosPickerItem] = []
    @State private var camara = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !fotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(fotos.enumerated()), id: \.offset) { n, d in
                            if let img = UIImage(data: d) {
                                Image(uiImage: img).resizable().scaledToFill().frame(width: 84, height: 84)
                                    .clipShape(.rect(cornerRadius: 12, style: .continuous))
                                    .overlay(alignment: .topTrailing) {
                                        Button { fotos.remove(at: n) } label: {
                                            Image(systemName: "xmark").font(.caption2.bold()).foregroundStyle(.white)
                                                .padding(5).background(.black.opacity(0.55), in: .circle)
                                        }
                                        .padding(4)
                                        .accessibilityLabel(Text("Quitar foto"))
                                    }
                            }
                        }
                    }
                }
            }
            if fotos.count < maximo {
                HStack(spacing: 10) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { camara = true } label: { Label("Hacer foto", systemImage: "camera") }.buttonStyle(.glass)
                    }
                    PhotosPicker(selection: $elegidas, maxSelectionCount: maximo - fotos.count, matching: .images) {
                        Label("Añadir fotos", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .onChange(of: elegidas) { _, items in
            Task {
                for item in items {
                    if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                        fotos.append(Self.comprimir(img))
                    }
                }
                elegidas = []
            }
        }
        .fullScreenCover(isPresented: $camara) {
            Camara { img in fotos.append(Self.comprimir(img)) }.ignoresSafeArea()
        }
    }

    static func comprimir(_ img: UIImage) -> Data {
        let lado: CGFloat = 1600
        let escala = min(1, lado / max(img.size.width, img.size.height))
        let tam = CGSize(width: img.size.width * escala, height: img.size.height * escala)
        let r = UIGraphicsImageRenderer(size: tam).image { _ in img.draw(in: CGRect(origin: .zero, size: tam)) }
        return r.jpegData(compressionQuality: 0.7) ?? Data()
    }
}

struct Camara: UIViewControllerRepresentable {
    let alHacer: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = .camera
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinador { Coordinador(self) }

    final class Coordinador: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let padre: Camara
        init(_ padre: Camara) { self.padre = padre }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { padre.alHacer(img) }
            padre.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { padre.dismiss() }
    }
}
