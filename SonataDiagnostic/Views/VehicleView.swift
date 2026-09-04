import SwiftUI

struct VehicleView: View {
    @EnvironmentObject private var obd: OBDLinkCXManager
    let demoMode: Bool
    private var snapshot: VehicleSnapshot { demoMode ? DemoVehicle.snapshot : obd.snapshot }
    private var scanned: Bool { demoMode || snapshot.hasAnyReading }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack { ScreenHeader(title: "Vehicle", subtitle: "Module response is truth — not the trim badge"); if demoMode { StatusBadge(text: "DEMO", color: SDTheme.amber) } }
                vehicleMap
                capabilityProfile
            }.padding(16)
        }
        .background(SDTheme.background).navigationBarHidden(true)
    }

    private var vehicleMap: some View {
        ZStack {
            VehicleRenderView(angle: .top).frame(height: 355)
            VStack {
                HStack {
                    VehicleStatusTile(title: "Battery", value: formatReading(snapshot.voltage, suffix: " V", digits: 1), icon: "bolt.fill", state: snapshot.voltage == nil ? .unavailable : .detected)
                    Spacer()
                    VehicleStatusTile(title: "Coolant", value: formatReading(snapshot.coolantF, suffix: "°F"), icon: "thermometer.medium", state: snapshot.coolantF == nil ? .unavailable : .detected)
                }
                Spacer()
                HStack {
                    VehicleStatusTile(title: "Check Engine", value: scanned ? (snapshot.dtcs.isEmpty ? "Off" : "On") : "Not scanned", icon: "engine.combustion.fill", state: scanned ? .detected : .unavailable, warning: !snapshot.dtcs.isEmpty)
                    Spacer()
                    VehicleStatusTile(title: "Fuel", value: formatReading(snapshot.fuelPct, suffix: "%"), icon: "fuelpump.fill", state: snapshot.fuelPct == nil ? .unavailable : .detected)
                }
            }.frame(height: 325)
        }
        .frame(maxWidth: .infinity).padding(12).background(SDTheme.panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 22).stroke(SDTheme.border, lineWidth: 0.7))
    }

    private var capabilityProfile: some View {
        VStack(spacing: 0) {
            CapabilityRow(title: "VIN", detail: snapshot.vin.isEmpty ? "Waiting for car" : snapshot.vin, state: snapshot.vin.isEmpty ? .unavailable : .detected)
            CapabilityRow(title: "Engine / ECM", detail: scanned ? "Standard OBD response" : "Not scanned", state: scanned ? .detected : .unavailable)
            CapabilityRow(title: "Standard OBD-II", detail: scanned ? "Read-only diagnostics" : "Not scanned", state: scanned ? .readOnly : .unavailable)
            CapabilityRow(title: "BCM / body electronics", detail: "Enhanced commands not verified", state: .research)
            CapabilityRow(title: "Smart Key", detail: "Writes safety-locked", state: .research)
            CapabilityRow(title: "ABS / ESC", detail: "No experimental probing", state: .readOnly)
            CapabilityRow(title: "SRS / Airbag", detail: "Protected system", state: .readOnly)
        }.premiumCard(padding: 0)
    }
}

private struct VehicleStatusTile: View {
    let title: String, value: String, icon: String
    let state: CapabilityState
    var warning = false
    private var color: Color { warning ? SDTheme.amber : state.color }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).foregroundStyle(color)
            Text(title).font(.caption2).foregroundStyle(SDTheme.muted)
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.65)
        }.frame(width: 92, alignment: .leading).padding(9).background(Color.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(SDTheme.border, lineWidth: 0.7))
    }
}

private struct CapabilityRow: View {
    let title: String, detail: String
    let state: CapabilityState
    var body: some View {
        HStack(spacing: 11) {
            Circle().stroke(state.color, lineWidth: 1.5).frame(width: 16, height: 16).overlay(Circle().fill(state == .detected ? state.color : .clear).frame(width: 7, height: 7))
            VStack(alignment: .leading, spacing: 2) { Text(title).font(.subheadline.weight(.medium)); Text(detail).font(.caption).foregroundStyle(SDTheme.muted) }
            Spacer()
            StatusBadge(text: state.rawValue, color: state.color)
        }.padding(.horizontal, 14).padding(.vertical, 11).overlay(alignment: .bottom) { Rectangle().fill(SDTheme.border).frame(height: 0.6) }
    }
}
