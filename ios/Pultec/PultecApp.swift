import SwiftUI

@main
struct PultecApp: App {
    @State private var estado = AppEstado()
    @State private var almacen = Almacen()

    init() {
        Marca.registrarFuentes()
    }

    var body: some Scene {
        WindowGroup {
            RaizView()
                .environment(estado)
                .environment(almacen)
                .preferredColorScheme(estado.tema.esquema)
                .task { await almacen.arrancar() }
        }
    }
}
