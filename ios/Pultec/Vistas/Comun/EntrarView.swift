import SwiftUI

/// «Entra en Pultec»: correo y contraseña, crear cuenta y recuperar contraseña.
struct EntrarView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.paleta) private var paleta
    @State private var correo = ""
    @State private var contrasena = ""
    @State private var ver = false
    @State private var creando = false
    @State private var trabajando = false
    @State private var error: String?
    @State private var recuperado = false
    @FocusState private var foco: Campo?

    enum Campo { case correo, contrasena }

    private var valido: Bool { correo.contains("@") && contrasena.count >= 6 }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image("Logo").resizable().scaledToFit().frame(width: 76, height: 76)
                    .clipShape(.rect(cornerRadius: 18, style: .continuous))
                    .padding(.top, 48)
                VStack(spacing: 6) {
                    Text(creando ? "Crea tu cuenta" : "Entra en Pultec").font(.system(size: 28, weight: .bold))
                    Text("Tus mantenimientos, en piloto automático.").font(.app(.subheadline)).foregroundStyle(.secondary)
                }
                VStack(spacing: 12) {
                    TextField("Correo", text: $correo)
                        .textContentType(.username).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($foco, equals: .correo).submitLabel(.next)
                        .onSubmit { foco = .contrasena }
                        .campoEntrada()
                    HStack {
                        Group {
                            if ver { TextField("Contraseña", text: $contrasena) }
                            else { SecureField("Contraseña", text: $contrasena) }
                        }
                        .textContentType(creando ? .newPassword : .password)
                        .focused($foco, equals: .contrasena).submitLabel(.go)
                        .onSubmit(entrar)
                        Button { ver.toggle() } label: { Image(systemName: ver ? "eye.slash" : "eye") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                            .accessibilityLabel(Text(ver ? "Ocultar contraseña" : "Ver contraseña"))
                    }
                    .campoEntrada()
                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.app(.footnote)).foregroundStyle(Color.pRojo)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Button(action: entrar) {
                    Group {
                        if trabajando { ProgressView().tint(.white) }
                        else { Text(creando ? "Crear cuenta" : "Entrar").font(.app(.body, .semibold)) }
                    }
                    .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(!valido || trabajando)

                VStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text(creando ? "¿Ya tienes cuenta?" : "¿No tienes cuenta?").foregroundStyle(.secondary)
                        Button(creando ? "Entra" : "Crea una") { withAnimation { creando.toggle(); error = nil } }
                    }
                    if !creando {
                        Button(recuperado ? "Te hemos enviado un correo" : "¿Has olvidado la contraseña?") {
                            Task {
                                do { try await almacen.recuperar(correo: correo); recuperado = true }
                                catch { self.error = String(localized: "Escribe tu correo para recuperarla.") }
                            }
                        }
                        .disabled(recuperado)
                    }
                }
                .font(.app(.subheadline))
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .fondoTema()
    }

    private func entrar() {
        guard valido, !trabajando else { return }
        trabajando = true
        error = nil
        Task {
            do {
                if creando { try await almacen.registrarse(correo: correo, contrasena: contrasena) }
                else { try await almacen.entrar(correo: correo, contrasena: contrasena) }
            } catch {
                self.error = error.localizedDescription
            }
            trabajando = false
        }
    }
}

private extension View {
    func campoEntrada() -> some View {
        modifier(CampoEntrada())
    }
}

private struct CampoEntrada: ViewModifier {
    @Environment(\.paleta) private var paleta
    func body(content: Content) -> some View {
        content
            .font(.app(.body))
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .background(paleta.superficie, in: .rect(cornerRadius: 14, style: .continuous))
    }
}
