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

    // Visite automatique pour la vidéo. Synchronisée avec scripts/record.sh par fichiers-repères dans Documents :
    // l'app écrit « step-N » quand l'écran N est prêt, le script fait la capture puis écrit « shot-N ».
    // (Avant : minutage fixe, décalé de plusieurs secondes sur les simulateurs récents → mauvaises captures.)
    @MainActor private func runTourIfNeeded() async {
        guard model.tour else { await model.reload(); return }
        func pause(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        for f in (try? FileManager.default.contentsOfDirectory(atPath: docs.path)) ?? [] where f.hasPrefix("step-") || f.hasPrefix("shot-") {
            try? FileManager.default.removeItem(at: docs.appendingPathComponent(f))
        }
        func step(_ n: Int) async {                       // écran prêt → attendre la capture (12 s max), 2 s mini pour la vidéo
            await pause(1.2)
            try? Data().write(to: docs.appendingPathComponent("step-\(n)"))
            let shot = docs.appendingPathComponent("shot-\(n)").path
            var waited = 0.0
            while !FileManager.default.fileExists(atPath: shot) && waited < 12 { await pause(0.25); waited += 0.25 }
            await pause(0.8)
        }
        await step(1)                                                          // calendrier
        selected = model.talks.first(where: { $0.status == .confirmed })
        await step(2)                                                          // fiche orateur
        selected = nil
        await pause(0.8)
        selected = model.talks.first(where: { $0.status == .toFill })
        await step(3)                                                          // samedi à pourvoir
        selected = nil
        await pause(0.8)
        withAnimation { model.tab = .settings }
        await step(4)                                                          // réglages
        withAnimation { model.tab = .calendar }
    }
}
}
