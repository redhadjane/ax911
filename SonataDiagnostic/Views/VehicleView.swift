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
            }.padding(18)
        }
        .background(SDTheme.background).navigationBarHidden(true)
    }

    private var vehicleMap: some View {
        ZStack {
            VehicleRenderView(angle: .top).frame(height: 420)
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
            }.frame(height: 385)
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
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(SDTheme.muted)
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(color).lineLimit(2).minimumScaleFactor(0.85)
        }.frame(width: 108, minHeight: 76, alignment: .leading).padding(11).background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(SDTheme.border, lineWidth: 0.7))
    }
}

private struct CapabilityRow: View {
    let title: String, detail: String
    let state: CapabilityState
    var body: some View {
        HStack(spacing: 11) {
            Circle().stroke(state.color, lineWidth: 1.5).frame(width: 20, height: 20).overlay(Circle().fill(state == .detected ? state.color : .clear).frame(width: 9, height: 9))
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 16, weight: .medium)); Text(detail).font(.system(size: 13)).foregroundStyle(SDTheme.muted) }
            Spacer()
            StatusBadge(text: state.rawValue, color: state.color)
        }.padding(.horizontal, 16).padding(.vertical, 14).overlay(alignment: .bottom) { Rectangle().fill(SDTheme.border).frame(height: 0.6) }
    }
}
