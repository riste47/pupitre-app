import SwiftUI

// Premier écran natif : le Calendrier des discours (cartes par samedi, couleurs de statut, fiche détaillée).
struct CalendarView: View {
    @EnvironmentObject var model: AppModel
    @Binding var selected: Talk?
    @State private var filter: Talk.Status? = nil
    @Environment(\.horizontalSizeClass) private var hsc

    private var shown: [Talk] { model.talks.filter { filter == nil || $0.status == filter } }
    private var columns: [GridItem] { hsc == .regular ? [GridItem(.adaptive(minimum: 300), spacing: 16)] : [GridItem(.flexible())] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SummaryStrip(talks: model.talks)
                    FilterBar(filter: $filter)
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(shown) { t in
                            TalkCard(talk: t).onTapGesture { selected = t }
                        }
                    }
                    Text("Prototype · données de démonstration")
                        .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendrier")
            .sheet(item: $selected) { t in TalkDetail(talk: t).presentationDetents([.medium, .large]) }
        }
    }
}

struct SummaryStrip: View {
    let talks: [Talk]
    var body: some View {
        HStack(spacing: 10) {
            stat("Confirmés", talks.filter { $0.status == .confirmed }.count, .green)
            stat("En attente", talks.filter { $0.status == .pending }.count, .orange)
            stat("À pourvoir", talks.filter { $0.status == .toFill }.count, .red)
        }
    }
    private func stat(_ l: String, _ n: Int, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(n)").font(.title.bold()).foregroundStyle(c)
            Text(l).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct FilterBar: View {
    @Binding var filter: Talk.Status?
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                chip("Tous", nil)
                chip("Confirmés", .confirmed)
                chip("En attente", .pending)
                chip("À pourvoir", .toFill)
                chip("Sorties", .outgoing)
            }
        }
    }
    private func chip(_ l: String, _ s: Talk.Status?) -> some View {
        Button { withAnimation(.snappy) { filter = s } } label: {
            Text(l).font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(filter == s ? Theme.accent : Color(.secondarySystemGroupedBackground), in: Capsule())
                .foregroundStyle(filter == s ? .white : .primary)
        }.buttonStyle(.plain)
    }
}

struct TalkCard: View {
    let talk: Talk
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Text(talk.date.formatted(.dateTime.day())).font(.title2.bold())
                Text(talk.date.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "fr_FR")))).font(.caption.weight(.semibold)).textCase(.uppercase)
            }
            .frame(width: 54, height: 58)
            .background(talk.status.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(talk.status.color)
            VStack(alignment: .leading, spacing: 4) {
                Label(talk.status.label, systemImage: talk.status.icon).font(.caption.weight(.bold)).foregroundStyle(talk.status.color)
                Text(talk.status == .toFill ? "Samedi à pourvoir" : talk.speaker).font(.headline)
                if !talk.congregation.isEmpty { Text(talk.congregation).font(.subheadline).foregroundStyle(.secondary) }
                if let p = talk.plan { Text("Plan n°\(p) · \(talk.theme)").font(.footnote).foregroundStyle(.secondary).lineLimit(2) }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(talk.status.color).frame(width: 4).padding(.vertical, 14) }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

struct TalkDetail: View {
    let talk: Talk
    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Date", value: talk.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(Locale(identifier: "fr_FR"))))
                    LabeledContent("Statut") { Label(talk.status.label, systemImage: talk.status.icon).foregroundStyle(talk.status.color) }
                }
                if talk.status == .toFill {
                    Section("Suggestions (orateurs extérieurs)") {
                        Text("Pupitre proposera ici les orateurs des autres assemblées disponibles ce samedi.").foregroundStyle(.secondary)
                    }
                } else {
                    Section("Orateur") {
                        LabeledContent("Nom", value: talk.speaker)
                        LabeledContent("Assemblée", value: talk.congregation)
                        if let p = talk.plan { LabeledContent("Plan", value: "n°\(p)") }
                        Text(talk.theme)
                    }
                }
            }
            .navigationTitle(talk.status == .toFill ? "Samedi à pourvoir" : talk.speaker)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
