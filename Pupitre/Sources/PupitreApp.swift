import SwiftUI

// Pupitre — app native (jalon 1 : prototype en simulateur).
// Le NAS reste le cerveau : l'app affiche Pupitre (coque web) et, petit à petit, des écrans natifs (le Calendrier d'abord).
@main
struct PupitreApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(Theme.accent)
        }
    }
}

enum Theme {
    static let accent = Color(red: 0.18, green: 0.44, blue: 0.93)
    static let warm = Color(red: 1.0, green: 0.48, blue: 0.0)
}

@MainActor
final class AppModel: ObservableObject {
    // Adresse de Pupitre (modifiable dans Réglages). Par défaut : l'accès extérieur Cloudflare.
    @AppStorage("serverURL") var serverURL: String = "https://app.pupitre-agen.com"
    @Published var tab: Tab = .calendar
    @Published var talks: [Talk] = Talk.demo
    @Published var isDemo = true
    @Published var notice: String? = nil
    @Published var loading = false
    private lazy var bridge = PupitreBridge()

    /// Charge le vrai calendrier depuis le NAS ; en cas d'échec, garde la démonstration et explique pourquoi.
    @MainActor func reload() async {
        guard !tour, !loading, let url = URL(string: serverURL) else { return }
        loading = true; defer { loading = false }
        do {
            let data = try await bridge.getJSON("/api/calendar6?months=6", server: url)
            let list = try Talk.fromCalendar6(data)
            talks = list; isDemo = false; notice = nil
        } catch {
            isDemo = true; talks = Talk.demo
            notice = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
    /// Lancement avec « -tour » : l'app passe d'elle-même d'un écran à l'autre (pour la vidéo du simulateur).
    let tour = ProcessInfo.processInfo.arguments.contains("-tour")

    enum Tab: Hashable { case calendar, web, settings }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @State private var selected: Talk?
    var body: some View {
        TabView(selection: $model.tab) {
            CalendarView(selected: $selected)
                .tabItem { Label("Calendrier", systemImage: "calendar") }
                .tag(AppModel.Tab.calendar)
            WebShellView()
                .tabItem { Label("Pupitre", systemImage: "globe") }
                .tag(AppModel.Tab.web)
            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape") }
                .tag(AppModel.Tab.settings)
        }
        .task { await runTourIfNeeded() }
    }

    // Visite automatique pour la vidéo (minutage calé sur scripts/record.sh : captures à 2 s, 6 s, 11 s et 17 s).
    @MainActor private func runTourIfNeeded() async {
        guard model.tour else { await model.reload(); return }
        func pause(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        await pause(3.5)
        selected = model.talks.first(where: { $0.status == .confirmed })      // fiche ouverte de 3,5 s à 8 s
        await pause(4.5)
        selected = nil
        await pause(1.5)
        selected = model.talks.first(where: { $0.status == .toFill })         // de 9,5 s à 13 s
        await pause(3.5)
        selected = nil
        await pause(1.5)
        withAnimation { model.tab = .settings }                               // de 14,5 s à 20 s
        await pause(5.5)
        withAnimation { model.tab = .calendar }
    }
}
