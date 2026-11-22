import Foundation
import WebKit

/// Lit les données de Pupitre en passant par une vue web invisible qui partage la connexion de l'onglet « Pupitre »
/// (même coffre de cookies : Cloudflare Access + session Pupitre). Rien n'est stocké en double, aucun mot de passe dans l'app.
@MainActor
final class PupitreBridge: NSObject, WKNavigationDelegate {
    enum BridgeError: LocalizedError {
        case notLoggedIn, unreachable(String), http(Int)
        var errorDescription: String? {
            switch self {
            case .notLoggedIn: return "Connectez-vous une fois dans l'onglet « Pupitre » : le Calendrier affichera alors vos vraies données."
            case .unreachable(let m): return "Pupitre est injoignable (\(m))."
            case .http(let c): return "Pupitre a répondu \(c)."
            }
        }
    }
    private let web: WKWebView
    private var loaded: CheckedContinuation<Void, Error>?
    private var base: URL?

    override init() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        web = WKWebView(frame: .zero, configuration: cfg)
        super.init()
        web.navigationDelegate = self
    }

    private func ensure(_ url: URL) async throws {
        if base == url, web.url?.host == url.host { return }
        base = url
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            loaded = c
            web.load(URLRequest(url: url.appendingPathComponent("api/version"), timeoutInterval: 15))
        }
    }

    func getJSON(_ path: String, server: URL) async throws -> Data {
        try await ensure(server)
        let js = """
        try {
          const r = await fetch(p, { credentials: "same-origin", cache: "no-store", headers: { Accept: "application/json" } });
          const t = await r.text();
          return JSON.stringify({ s: r.status, t: t, ct: r.headers.get("content-type") || "" });
        } catch (e) { return JSON.stringify({ s: 0, t: String(e), ct: "" }); }
        """
        // Version « à rappel » (Objective-C) : la variante async passe par libswiftWebKit, absente des anciens iOS.
        let any: Any? = try await withCheckedThrowingContinuation { c in
            web.callAsyncJavaScript(js, arguments: ["p": path], in: nil, in: .page) { r in
                switch r { case .success(let v): c.resume(returning: v); case .failure(let e): c.resume(throwing: e) }
            }
        }
        guard let str = any as? String, let d = str.data(using: .utf8),
              let o = try JSONSerialization.jsonObject(with: d) as? [String: Any],
              let status = o["s"] as? Int, let text = o["t"] as? String else { throw BridgeError.unreachable("réponse illisible") }
        let ct = (o["ct"] as? String) ?? ""
        if status == 0 || status == 401 || status == 403 || !ct.contains("json") { throw BridgeError.notLoggedIn }
        if status >= 400 { throw BridgeError.http(status) }
        return Data(text.utf8)
    }

    func webView(_ w: WKWebView, didFinish n: WKNavigation!) { loaded?.resume(); loaded = nil }
    func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { loaded?.resume(throwing: BridgeError.unreachable(e.localizedDescription)); loaded = nil; base = nil }
    func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { loaded?.resume(throwing: BridgeError.unreachable(e.localizedDescription)); loaded = nil; base = nil }
}
