import Foundation
import Security

/// La sesión de Supabase se guarda en el Llavero del iPhone (no en UserDefaults).
enum Llavero {
    private static let servicio = "com.pultec.app"

    static func guardar(_ datos: Data, _ clave: String) {
        borrar(clave)
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: clave,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: datos,
        ]
        SecItemAdd(q as CFDictionary, nil)
    }

    static func leer(_ clave: String) -> Data? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: clave,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var r: AnyObject?
        return SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess ? r as? Data : nil
    }

    static func borrar(_ clave: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: clave,
        ]
        SecItemDelete(q as CFDictionary)
    }
}
