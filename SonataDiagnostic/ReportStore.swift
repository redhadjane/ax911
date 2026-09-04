import Foundation

struct SavedDiagnosticReport: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let vin: String
    let codes: [String]
    let rpm: Double?
    let speedMph: Double?
    let coolantF: Double?
    let voltage: Double?
    let demo: Bool
}

final class ReportStore: ObservableObject {
    @Published private(set) var reports: [SavedDiagnosticReport] = []
    private let key = "SonataDiagnostic.savedReports.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: key), let decoded = try? JSONDecoder().decode([SavedDiagnosticReport].self, from: data) else { return }
        reports = decoded
    }

    func save(snapshot: VehicleSnapshot, demo: Bool) {
        reports.insert(SavedDiagnosticReport(id: UUID(), createdAt: Date(), vin: snapshot.vin, codes: snapshot.dtcs, rpm: snapshot.rpm, speedMph: snapshot.speedMph, coolantF: snapshot.coolantF, voltage: snapshot.voltage, demo: demo), at: 0)
        guard let data = try? JSONEncoder().encode(reports) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
