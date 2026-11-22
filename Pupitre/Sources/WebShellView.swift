import SwiftUI
import WebKit

// Coque web : tout Pupitre, tel qu'il est sur le NAS, en plein écran — comme la version web ajoutée à l'écran d'accueil.
// Pas de barre de titre ni de barre d'onglets natives par-dessus : Pupitre garde sa propre barre du bas, ses couleurs
// et gère lui-même les zones de l'encoche et du bas de l'écran.
struct WebShellView: View {
    @EnvironmentObject var model: AppModel
    @State private var loading = true
    @State private var failed: String? = nil
    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.94, blue: 0.89).ignoresSafeArea()          // fond clair en attendant la page (plus de noir)
            if let url = URL(string: model.serverURL) {
                WebView(url: url, loading: $loading, failed: $failed).ignoresSafeArea()
            }
            if loading && failed == nil { ProgressView("Connexion à Pupitre…").tint(.secondary) }
            if let f = failed {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark").font(.largeTitle)
                    Text("Pupitre ne répond pas").font(.headline)
                    Text(f).font(.footnote).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Réessayer") { failed = nil; loading = true; NotificationCenter.default.post(name: .pupitreReload, object: nil) }
                        .buttonStyle(.borderedProminent)
                }.padding(32).foregroundStyle(.black)
            }
        }
        .preferredColorScheme(.light)
    }
}

extension Notification.Name { static let pupitreReload = Notification.Name("pupitreReload") }

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var loading: Bool
    @Binding var failed: String?
    func makeCoordinator() -> Coord { Coord(self) }
    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()                 // garde la session (cookies, réglages de la page) entre deux lancements
        cfg.allowsInlineMediaPlayback = true
        let w = WKWebView(frame: .zero, configuration: cfg)
        w.navigationDelegate = context.coordinator
        w.allowsBackForwardNavigationGestures = true
        w.isOpaque = false
        w.backgroundColor = .clear
        w.scrollView.backgroundColor = .clear
        w.scrollView.contentInsetAdjustmentBehavior = .never   // la page gère l'encoche (env(safe-area-inset-*)), comme en mode web app
        w.pageZoom = 1.0                                        // taille réelle : rien de grossi
        let refresh = UIRefreshControl()                        // tirer vers le bas pour recharger
        refresh.addTarget(context.coordinator, action: #selector(Coord.pull(_:)), for: .valueChanged)
        w.scrollView.refreshControl = refresh
        context.coordinator.web = w
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coord.retry), name: .pupitreReload, object: nil)
        w.load(URLRequest(url: url))
        return w
    }
    func updateUIView(_ w: WKWebView, context: Context) {}
    final class Coord: NSObject, WKNavigationDelegate {
        let parent: WebView
        weak var web: WKWebView?
        init(_ p: WebView) { parent = p }
        @objc func pull(_ r: UIRefreshControl) { web?.reload(); DispatchQueue.main.asyncAfter(deadline: .now() + 1) { r.endRefreshing() } }
        @objc func retry() { if let w = web { if w.url == nil { w.load(URLRequest(url: parent.url)) } else { w.reload() } } }
        func webView(_ w: WKWebView, didFinish n: WKNavigation!) { parent.loading = false; parent.failed = nil }
        func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { fail(e) }
        func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { fail(e) }
        private func fail(_ e: Error) {
            parent.loading = false
            if (e as NSError).code == NSURLErrorCancelled { return }
            parent.failed = e.localizedDescription
        }
    }
}
