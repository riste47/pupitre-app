import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        NavigationStack {
            Form {
                Section("Adresse de Pupitre") {
                    TextField("https://…", text: $model.serverURL)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Par défaut : l'accès extérieur sécurisé (Cloudflare). Chez vous, l'adresse du NAS fonctionne aussi.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Assistant Claude") {
                    Label("Bientôt : poser une question à Claude depuis l'app", systemImage: "sparkles")
                        .foregroundStyle(.secondary)
                }
                Section("À propos") {
                    LabeledContent("Version", value: "0.1.0 · prototype")
                    LabeledContent("Écrans natifs", value: "Calendrier")
                }
            }
            .navigationTitle("Réglages")
        }
    }
}
