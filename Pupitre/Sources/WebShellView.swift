import SwiftUI
import WebKit

// Coque web : tout Pupitre, tel qu'il est sur le NAS, en attendant que chaque écran devienne natif.
struct WebShellView: View {
    @EnvironmentObject var model: AppModel
    @State private var loading = true
    var body: some View {
        NavigationStack {
            ZStack {
                if let url = URL(string: model.serverURL) {
                    WebView(url: url, loading: $loading).ignoresSafeArea(edges: .bottom)
                }
                if loading { ProgressView("Connexion à Pupitre…") }
            }
            .navigationTitle("Pupitre")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var loading: Bool
    func makeCoordinator() -> Coord { Coord(self) }
    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default() // garde la session (cookies) entre deux lancements
        let w = WKWebView(frame: .zero, configuration: cfg)
        w.navigationDelegate = context.coordinator
        w.allowsBackForwardNavigationGestures = true
        w.load(URLRequest(url: url))
        return w
    }
    func updateUIView(_ w: WKWebView, context: Context) {}
    final class Coord: NSObject, WKNavigationDelegate {
        let parent: WebView
        init(_ p: WebView) { parent = p }
        func webView(_ w: WKWebView, didFinish n: WKNavigation!) { parent.loading = false }
        func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { parent.loading = false }
        func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { parent.loading = false }
    }
}
