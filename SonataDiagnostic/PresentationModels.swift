import Foundation
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home = "Home", live = "Live", diagnostics = "Diagnostics", settings = "Settings", vehicle = "Vehicle"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .live: return "waveform.path.ecg"
        case .diagnostics: return "stethoscope"
        case .settings: return "slider.horizontal.3"
        case .vehicle: return "car.top.radiowaves.rear.left.and.rear.right.fill"
        }
    }
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
    static let snapshot = VehicleSnapshot(vin: "5NPE34AF0FH012345", dtcs: ["P200A"], rpm: 798, speedMph: 0, coolantF: 194, loadPct: 21, throttlePct: 11.4, intakeAirF: 82, shortFuelTrimPct: 2.3, longFuelTrimPct: 3.1, fuelPct: 62, voltage: 12.4)
}

extension VehicleSnapshot {
    var hasAnyReading: Bool { !vin.isEmpty || !dtcs.isEmpty || rpm != nil || speedMph != nil || coolantF != nil || voltage != nil }
}
