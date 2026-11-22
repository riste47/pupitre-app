import Foundation
import SwiftUI

struct Talk: Identifiable, Hashable {
    enum Status: String { case confirmed, pending, toFill, outgoing
        var label: String {
            switch self {
            case .confirmed: return "Confirmé"
            case .pending: return "En attente de réponse"
            case .toFill: return "À pourvoir"
            case .outgoing: return "Sortie"
            }
        }
        var color: Color {
            switch self {
            case .confirmed: return .green
            case .pending: return .orange
            case .toFill: return .red
            case .outgoing: return .purple
            }
        }
        var icon: String {
            switch self {
            case .confirmed: return "checkmark.seal.fill"
            case .pending: return "hourglass"
            case .toFill: return "exclamationmark.circle.fill"
            case .outgoing: return "car.fill"
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
}
