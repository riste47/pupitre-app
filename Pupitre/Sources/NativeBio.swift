import Foundation
import WebKit
import LocalAuthentication
import Security

// 0.2.2 : Face ID pour le verrou des Réglages de Pupitre, DANS l'app.
// Dans une app, la vue web ne peut pas utiliser les clés d'accès de Safari (WebAuthn → NotAllowedError) sans
// le programme Apple Developer payant. L'app fournit donc son propre Face ID à la page : window.PupitreNativeBio.
// Le code à 6 chiffres est rangé dans le trousseau d'Apple de CET appareil, protégé par Face ID
// (biometryCurrentSet : un nouveau visage enregistré dans l'iPad efface l'accès), jamais synchronisé ni affiché.
enum NativeBio {
    static let script = """
    (function(){
      if (window.PupitreNativeBio) return;
      var h = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.pupitreBio;
      if (!h) return;
      function call(action, pin){ return h.postMessage({ action: action, pin: pin || "" }); }
      window.PupitreNativeBio = {
        native: true,
        has: function(){ return call("has"); },
        save: function(pin){ return call("save", pin); },
        read: function(){ return call("read"); },
        forget: function(){ return call("forget"); }
      };
    })();
    """
    private static let service = "com.riste47.pupitre.verrou"
    private static let account = "code-reglages"

    static func install(on cfg: WKWebViewConfiguration) {
        let uc = cfg.userContentController
        uc.addScriptMessageHandler(Handler(), contentWorld: .page, name: "pupitreBio")
        uc.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    }

    final class Handler: NSObject, WKScriptMessageHandlerWithReply {
        func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage,
                                   replyHandler: @escaping (Any?, String?) -> Void) {
            let body = message.body as? [String: Any] ?? [:]
            let action = body["action"] as? String ?? ""
            let pin = body["pin"] as? String ?? ""
            let reply: (Any?, String?) -> Void = { v, e in DispatchQueue.main.async { replyHandler(v, e) } }
            DispatchQueue.global(qos: .userInitiated).async {
                switch action {
                case "has": reply(NativeBio.exists(), nil)
                case "forget": NativeBio.delete(); reply(true, nil)
                case "save":
                    guard pin.range(of: "^[0-9]{6}$", options: .regularExpression) != nil else { reply(nil, "Code invalide."); return }
                    NativeBio.save(pin) { ok, err in reply(ok ? true : nil, ok ? nil : err) }
                case "read": NativeBio.read { v, err in reply(v, err) }
                default: reply(nil, "Action inconnue.")
                }
            }
        }
    }

    static func exists() -> Bool {
        let ctx = LAContext(); ctx.interactionNotAllowed = true
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecUseAuthenticationContext as String: ctx]
        let st = SecItemCopyMatching(q as CFDictionary, nil)
        return st == errSecSuccess || st == errSecInteractionNotAllowed
    }
    static func delete() {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(q as CFDictionary)
    }
    /// Demande Face ID (pour confirmer que c'est bien le propriétaire), puis range le code sous Face ID.
    static func save(_ pin: String, done: @escaping (Bool, String?) -> Void) {
        let ctx = LAContext()
        var e: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &e) else {
            done(false, "Face ID n'est pas disponible ou pas configuré sur cet appareil (Réglages › Face ID et code)."); return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Activer Face ID pour déverrouiller les Réglages de Pupitre") { ok, err in
            guard ok else { done(false, "Face ID annulé."); return }
            guard let ac = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, nil) else {
                done(false, "Trousseau indisponible."); return
            }
            delete()
            let add: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                      kSecAttrAccount as String: account, kSecAttrAccessControl as String: ac,
                                      kSecValueData as String: Data(pin.utf8), kSecUseAuthenticationContext as String: ctx]
            let st = SecItemAdd(add as CFDictionary, nil)
            done(st == errSecSuccess, st == errSecSuccess ? nil : "Enregistrement impossible (erreur \(st)).")
        }
    }
    /// Face ID → renvoie le code (nil s'il n'y a rien d'enregistré ou si le visage a changé).
    static func read(done: @escaping (String?, String?) -> Void) {
        let ctx = LAContext()
        ctx.localizedReason = "Déverrouiller les Réglages de Pupitre"
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne, kSecUseAuthenticationContext as String: ctx]
        var out: CFTypeRef?
        let st = SecItemCopyMatching(q as CFDictionary, &out)
        switch st {
        case errSecSuccess:
            if let d = out as? Data, let s = String(data: d, encoding: .utf8) { done(s, nil) } else { done(nil, nil) }
        case errSecItemNotFound: done(nil, nil)
        case errSecUserCanceled, errSecAuthFailed: done(nil, "Face ID annulé.")
        default: done(nil, "Face ID impossible (erreur \(st)).")
        }
    }
}
