import SwiftUI

struct VehicleView: View {
    @EnvironmentObject private var obd: OBDLinkCXManager
    let demoMode: Bool
    let scenario: DemoScenario
    @State private var tiltX: Double = 0
    @State private var tiltY: Double = 0
    private var snapshot: VehicleSnapshot { demoMode ? DemoVehicle.snapshot(for: scenario) : obd.snapshot }
    private var scanned: Bool { demoMode || snapshot.hasAnyReading }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 13) {
                HStack(alignment: .top) {
                    ScreenHeader(title: "Vehicle intelligence", subtitle: "Touch the vehicle to explore its live signal map.")
                    StatusBadge(text: "INTERACTIVE", color: SDTheme.cyan)
                }
                vehicleMap
                SectionLabel(text: "Detected capabilities")
                capabilityProfile
            }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }

    private var vehicleMap: some View {
        ZStack {
            VehicleGrid().opacity(0.7)
            Ellipse().fill(SDTheme.green.opacity(0.08)).frame(width: 180, height: 320).blur(radius: 28)
            VehicleRenderView(angle: .top)
                .frame(width: 145, height: 350)
                .rotation3DEffect(.degrees(tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.75)
                .rotation3DEffect(.degrees(tiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.75)
                .shadow(color: .black.opacity(0.7), radius: 18, y: 16)
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    tiltY = min(12, max(-12, Double(value.translation.width / 12)))
                    tiltX = min(9, max(-9, Double(-value.translation.height / 15)))
                }.onEnded { _ in withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { tiltX = 0; tiltY = 0 } })
            VStack(spacing: 0) {
                HStack {
                    VehicleStatusTile(title: "Battery", value: formatReading(snapshot.voltage, suffix: " V", digits: 1), icon: "bolt.fill", state: snapshot.voltage == nil ? .unavailable : .detected)
                    Spacer()
                    VehicleStatusTile(title: "Coolant", value: formatReading(snapshot.coolantF, suffix: "°F"), icon: "thermometer.medium", state: snapshot.coolantF == nil ? .unavailable : .detected)
                }
                Spacer()
                HStack {
                    VehicleStatusTile(title: "Driver Door", value: demoMode ? "Open" : "Not available", icon: "car.side.rear.open", state: demoMode ? .detected : .unavailable, warning: demoMode)
                    Spacer()
                    VehicleStatusTile(title: "Fuel Level", value: formatReading(snapshot.fuelPct, suffix: "%"), icon: "fuelpump.fill", state: snapshot.fuelPct == nil ? .unavailable : .detected)
                }
                Spacer()
                HStack {
                    VehicleStatusTile(title: "Intake System", value: snapshot.dtcs.contains("P200A") ? "Issue" : "Normal", icon: "exclamationmark.triangle.fill", state: scanned ? .detected : .unavailable, warning: snapshot.dtcs.contains("P200A"))
                    Spacer()
                    VehicleStatusTile(title: "Check Engine", value: scanned ? (snapshot.dtcs.isEmpty ? "Off" : "On") : "Not scanned", icon: "engine.combustion.fill", state: scanned ? .detected : .unavailable, warning: !snapshot.dtcs.isEmpty)
                }
                HStack(spacing: 5) {
                    Text("Mileage").foregroundStyle(SDTheme.muted)
                    Text(demoMode ? "128,540 mi" : "Not available").foregroundStyle(.white).fontWeight(.semibold)
                    if demoMode { StatusBadge(text: "DEMO", color: SDTheme.amber) }
                }
                .font(.system(size: 11)).padding(.horizontal, 14).padding(.vertical, 9)
                .background(SDTheme.panel, in: Capsule()).overlay(Capsule().stroke(SDTheme.border, lineWidth: 0.7))
                Text("DRAG TO TILT").font(.system(size: 8.5, weight: .bold)).tracking(1.3).foregroundStyle(SDTheme.tertiary).padding(.top, 7)
            }.frame(height: 438)
        }
        .frame(maxWidth: .infinity).frame(height: 464).padding(10)
        .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(SDTheme.border, lineWidth: 0.7))
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
        }.premiumCard(padding: 0, radius: 19)
    }
}

private struct VehicleGrid: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                for x in stride(from: 0.0, through: proxy.size.width, by: 42) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                }
                for y in stride(from: 0.0, through: proxy.size.height, by: 42) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
            }.stroke(Color.white.opacity(0.045), lineWidth: 0.6)
        }
    }
}

private struct VehicleStatusTile: View {
    let title: String, value: String, icon: String
    let state: CapabilityState
    var warning = false
    private var color: Color { warning ? SDTheme.amber : state.color }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
            Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(SDTheme.muted).lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(.system(size: 12.5, weight: .bold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.75)
        }.frame(width: 95, alignment: .leading).frame(minHeight: 57, alignment: .leading).padding(9).background(Color.black.opacity(0.66), in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(SDTheme.border, lineWidth: 0.7))
    }
}

private struct CapabilityRow: View {
    let title: String, detail: String
    let state: CapabilityState
    var body: some View {
        HStack(spacing: 11) {
            Circle().stroke(state.color, lineWidth: 1.5).frame(width: 20, height: 20).overlay(Circle().fill(state == .detected ? state.color : .clear).frame(width: 9, height: 9))
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 14, weight: .semibold)); Text(detail).font(.system(size: 11.5)).foregroundStyle(SDTheme.muted).lineLimit(1).minimumScaleFactor(0.8) }
            Spacer()
            StatusBadge(text: state.rawValue, color: state.color)
        }.padding(.horizontal, 15).padding(.vertical, 12).overlay(alignment: .bottom) { Rectangle().fill(SDTheme.border).frame(height: 0.6) }
    }
}
