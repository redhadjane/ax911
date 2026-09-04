import Foundation
import SwiftUI

enum AppRoute: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case live = "Live Data"
    case diagnostics = "Diagnostics"
    case vehicle = "3D Vehicle"
    case settings = "Car Settings"
    case reports = "Reports"
    case maintenance = "Maintenance"
    case logging = "Data Logging"
    case profile = "Vehicle Profile"
    case about = "About"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .overview: return "house"
        case .live: return "chart.bar.xaxis"
        case .diagnostics: return "car.rear.waves.up"
        case .vehicle: return "car.top"
        case .settings: return "slider.horizontal.3"
        case .reports: return "doc.text"
        case .maintenance: return "wrench.and.screwdriver"
        case .logging: return "chart.bar.xaxis"
        case .profile: return "square.grid.2x2"
        case .about: return "info.circle"
        }
    }

    static let bottomRoutes: [AppRoute] = [.overview, .live, .diagnostics, .settings]
    static let menuRoutes: [AppRoute] = [.overview, .live, .diagnostics, .vehicle, .settings, .reports, .maintenance, .logging, .profile, .about]
}

enum DemoScenario: String, CaseIterable, Identifiable {
    case intake = "P200A · Intake airflow issue"
    case healthy = "Healthy vehicle"
    case battery = "P0562 · Low system voltage"
    var id: String { rawValue }
}

enum CapabilityState: String {
    case detected = "Detected", unavailable = "Not available", research = "Research", readOnly = "Read-only"
    var color: Color {
        switch self {
        case .detected: return SDTheme.green
        case .unavailable, .readOnly: return SDTheme.muted
        case .research: return SDTheme.amber
        }
    }
}

enum DiagnosticSeverity: String, Hashable {
    case advisory = "Advisory", moderate = "Moderate", serious = "Serious"
    var color: Color {
        switch self {
        case .advisory: return SDTheme.green
        case .moderate: return SDTheme.amber
        case .serious: return SDTheme.red
        }
    }
}

struct DiagnosticRecord: Identifiable, Hashable {
    let code: String
    let headline: String
    let explanation: String
    let definition: String
    let severity: DiagnosticSeverity
    let symptoms: [String]
    let causes: [String]
    let inspection: String
    var id: String { code }

    static func record(for code: String) -> DiagnosticRecord {
        switch code {
        case "P200A":
            return DiagnosticRecord(code: code, headline: "Engine airflow control needs attention.", explanation: "A mechanism inside the intake manifold is not moving the way the engine computer expects. The car may still drive normally, but airflow control should be inspected.", definition: "Intake Manifold Runner Performance, Bank 1", severity: .moderate, symptoms: ["Hesitation or weaker acceleration", "Reduced fuel economy", "Check-engine light with no obvious drivability change"], causes: ["Runner linkage or actuator sticking", "Connector or wiring fault", "Vacuum leak", "Carbon buildup"], inspection: "Inspect runner linkage and actuator movement, connector and wiring integrity, vacuum routing, and deposits. Compare commanded versus actual runner position only if verified Hyundai enhanced PIDs become available.")
        case "P0562":
            return DiagnosticRecord(code: code, headline: "Vehicle voltage has fallen too low.", explanation: "The engine computer measured less electrical voltage than expected. Check the battery, charging system, cable connections, and unusual electrical loads.", definition: "System Voltage Low", severity: .serious, symptoms: ["Slow starting", "Dim or unstable lighting", "Multiple warning lights", "Possible stalling if voltage becomes severe"], causes: ["Weak battery", "Charging-system fault", "Loose or corroded connection", "Excess electrical load"], inspection: "Load-test the battery, verify alternator output under load, and inspect primary power and ground connections before replacing components.")
        default:
            return DiagnosticRecord(code: code, headline: "The engine computer found a stored fault.", explanation: "The vehicle returned this code through standard OBD-II. A verified plain-language definition is not yet installed, so the app preserves the original code without guessing.", definition: "Definition not available in the offline library", severity: .moderate, symptoms: ["Symptoms depend on the system and operating condition"], causes: ["Not available from this vehicle"], inspection: "Use the original DTC and manufacturer service information for diagnosis.")
        }
    }
}

enum DemoVehicle {
    static func snapshot(for scenario: DemoScenario) -> VehicleSnapshot {
        switch scenario {
        case .intake:
            return VehicleSnapshot(vin: "5NPE34AF0FH012345", dtcs: ["P200A"], rpm: 800, speedMph: 0, coolantF: 194, loadPct: 21, throttlePct: 11.4, intakeAirF: 82, shortFuelTrimPct: 11.8, longFuelTrimPct: 7.4, fuelPct: 62, voltage: 14.1)
        case .healthy:
            return VehicleSnapshot(vin: "5NPE34AF0FH012345", dtcs: [], rpm: 782, speedMph: 0, coolantF: 191, loadPct: 18, throttlePct: 10.2, intakeAirF: 80, shortFuelTrimPct: 2.1, longFuelTrimPct: 3.2, fuelPct: 62, voltage: 14.2)
        case .battery:
            return VehicleSnapshot(vin: "5NPE34AF0FH012345", dtcs: ["P0562"], rpm: 0, speedMph: 0, coolantF: 76, loadPct: 0, throttlePct: 9.8, intakeAirF: 75, shortFuelTrimPct: 0, longFuelTrimPct: 2.4, fuelPct: 61, voltage: 11.7)
        }
    }
}

extension VehicleSnapshot {
    var hasAnyReading: Bool { !vin.isEmpty || !dtcs.isEmpty || rpm != nil || speedMph != nil || coolantF != nil || voltage != nil }
}
