import Foundation
import SwiftUI

struct Talk: Identifiable, Hashable {
    enum Status: String { case confirmed, pending, toConfirm, toFill, outgoing, event
        var label: String {
            switch self {
            case .confirmed: return "Confirmé"
            case .pending: return "En attente de réponse"
            case .toFill: return "À pourvoir"
            case .outgoing: return "Sortie"
            case .toConfirm: return "À confirmer"
            case .event: return "Événement"
            }
        }
        var color: Color {
            switch self {
            case .confirmed: return .green
            case .pending: return .orange
            case .toFill: return .red
            case .outgoing: return .purple
            case .toConfirm: return .blue
            case .event: return .teal
            }
        }
        var icon: String {
            switch self {
            case .confirmed: return "checkmark.seal.fill"
            case .pending: return "hourglass"
            case .toFill: return "exclamationmark.circle.fill"
            case .outgoing: return "car.fill"
            case .toConfirm: return "pin.fill"
            case .event: return "star.fill"
            }
        }
    }
    let id = UUID()
    let date: Date
    let speaker: String
    let congregation: String
    let plan: Int?
    let theme: String
    let status: Status
    var isLocal: Bool { congregation == "Agen Le Passage" }

    // Données de démonstration (noms inventés) : le prototype tourne sans le NAS, dans le simulateur de GitHub.
    static let demo: [Talk] = {
        let cal = Calendar(identifier: .gregorian)
        var start = cal.startOfDay(for: Date())
        while cal.component(.weekday, from: start) != 7 { start = cal.date(byAdding: .day, value: 1, to: start)! }
        let rows: [(String, String, Int?, String, Status)] = [
            ("Paul Martin", "Agen Le Passage", 12, "Qui peut vraiment nous guider ?", .confirmed),
            ("Jean Dupuis", "Nérac", 47, "Une espérance solide pour l'avenir", .confirmed),
            ("—", "", nil, "Samedi à pourvoir", .toFill),
            ("Luc Bernard", "Valence d'Agen", 105, "Trouver la paix dans un monde agité", .pending),
            ("Marc Petit", "Agen Le Passage", 33, "La vraie richesse", .outgoing),
            ("Simon Laurent", "Agen Bon Encontre", 76, "Des familles heureuses", .confirmed),
            ("—", "", nil, "Samedi à pourvoir", .toFill),
            ("André Morel", "Marmande", 150, "Pourquoi garder confiance ?", .pending),
        ]
        return rows.enumerated().map { i, r in
            Talk(date: cal.date(byAdding: .day, value: 7 * i, to: start)!, speaker: r.0, congregation: r.1, plan: r.2, theme: r.3, status: r.4)
        }
    }()

    // ——— Vraies données : réponse de /api/calendar6 (la même que le Calendrier web) ———
    static func fromCalendar6(_ data: Data) throws -> [Talk] {
        struct Who: Decodable { let name: String?; let status: String?; let planNumber: Int? }
        struct Sat: Decodable {
            let date: String; let past: Bool?; let kind: String
            let name: String?; let external: Bool?; let status: String?
            let planNumber: Int?; let planTitle: String?; let label: String?
        }
        struct Root: Decodable { let saturdays: [Sat]; let outgoing: [String: [Who]]? }
        let root = try JSONDecoder().decode(Root.self, from: data)
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        var out: [Talk] = []
        for s in root.saturdays where s.past != true {
            guard let d = f.date(from: s.date) else { continue }
            switch s.kind {
            case "talk":
                let st: Status
                switch s.status ?? "" {
                case "confirme", "confirme-verrouille", "confirme-tacite": st = .confirmed
                case "invite", "envoye": st = .pending
                default: st = .toConfirm
                }
                out.append(Talk(date: d, speaker: s.name ?? "Orateur", congregation: s.external == true ? "Orateur invité" : "Orateur local",
                                plan: s.planNumber, theme: s.planTitle ?? "", status: st))
            case "event":
                out.append(Talk(date: d, speaker: s.label ?? "Événement", congregation: "", plan: nil, theme: s.label ?? "", status: .event))
            default:
                out.append(Talk(date: d, speaker: "—", congregation: "", plan: nil, theme: "Samedi à pourvoir", status: .toFill))
            }
            for o in root.outgoing?[s.date] ?? [] {
                out.append(Talk(date: d, speaker: o.name ?? "Orateur", congregation: "Sortie", plan: o.planNumber, theme: "", status: .outgoing))
            }
        }
        return out
    }
}
