import SwiftUI

struct LandingView: View {
    @EnvironmentObject private var obd: OBDLinkCXManager
    @Binding var demoMode: Bool

    private var snapshot: VehicleSnapshot { demoMode ? DemoVehicle.snapshot : obd.snapshot }
    private var connected: Bool { demoMode || obd.state == .connected || obd.state == .reading || obd.state == .finished }
    private var busy: Bool { obd.state == .scanning || obd.state == .connecting || obd.state == .reading }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                brandHero
                connectionCard
                if connected { overview }
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 24)
        }
        .background(SDTheme.background).toolbar(.hidden, for: .navigationBar)
    }

    private var brandHero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SONATA").font(.system(size: 42, weight: .bold, design: .rounded)).tracking(1.2)
            Text("DIAGNOSTIC").font(.system(size: 30, weight: .light, design: .rounded)).tracking(1.8)
            Text("Your car. Your data. No subscriptions.").font(.system(size: 16)).foregroundStyle(SDTheme.muted).padding(.top, 9)
            VehicleRenderView(angle: .hero).frame(maxWidth: .infinity).frame(height: 245).padding(.top, 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var connectionCard: some View {
        VStack(spacing: 13) {
            HStack(spacing: 11) {
                Circle().fill(connectionColor.opacity(0.12)).frame(width: 42, height: 42).overlay(Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 17, weight: .bold)).foregroundStyle(connectionColor))
                VStack(alignment: .leading, spacing: 2) {
                    Text("OBDLink CX").font(.system(size: 18, weight: .semibold))
                    Text(demoMode ? "Demo Mode — sample data" : obd.message).font(.system(size: 13)).foregroundStyle(SDTheme.muted).lineLimit(2)
                }
                Spacer()
                if busy { ProgressView().tint(SDTheme.green) } else { StatusBadge(text: connectionLabel, color: connectionColor) }
            }
            if busy { ProgressView(value: Double(obd.progress), total: 100).tint(SDTheme.green) }
            if !snapshot.vin.isEmpty {
                Divider().overlay(SDTheme.border)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("2015 Hyundai Sonata").font(.system(size: 16, weight: .semibold))
                        Text("VIN · \(snapshot.vin)").font(.system(size: 12, design: .monospaced)).foregroundStyle(SDTheme.muted)
                    }
                    Spacer()
                }
            }
            Button {
                if demoMode { demoMode = false }
                if busy || connected { obd.disconnect() } else { obd.connect() }
            } label: { Text(busy || (!demoMode && connected) ? "Disconnect" : "Connect") }
            .buttonStyle(WhiteButtonStyle())
            Button {
                demoMode.toggle()
                if demoMode { obd.disconnect() }
            } label: {
                Label(demoMode ? "Exit Demo Mode" : "Demo Mode", systemImage: "play.circle").font(.system(size: 14, weight: .semibold)).foregroundStyle(demoMode ? SDTheme.amber : SDTheme.muted)
            }
            .buttonStyle(.plain)
        }
        .premiumCard()
    }

    private var overview: some View {
        VStack(spacing: 13) {
            HStack { SectionLabel(text: "Overview"); if demoMode { StatusBadge(text: "DEMO", color: SDTheme.amber) } }
            VehicleRenderView(angle: .hero).frame(height: 155)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                SystemHealthCard(name: "Engine", detail: snapshot.dtcs.isEmpty ? "No active codes" : "\(snapshot.dtcs.count) issue detected", state: .detected, warning: !snapshot.dtcs.isEmpty)
                SystemHealthCard(name: "Emissions", detail: snapshot.dtcs.isEmpty ? "Standard OBD ready" : "Review engine DTC", state: .detected, warning: !snapshot.dtcs.isEmpty)
                if demoMode {
                    SystemHealthCard(name: "Transmission", detail: "Demo capability", state: .detected)
                    SystemHealthCard(name: "Electrical", detail: "Demo capability", state: .detected)
                    SystemHealthCard(name: "Intake System", detail: "Issue detected", state: .detected, warning: true)
                    SystemHealthCard(name: "ABS", detail: "Demo capability", state: .detected)
                }
            }
            if hasMetrics {
                SectionLabel(text: "Selected live data")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                    if snapshot.rpm != nil { MetricCard(title: "RPM", value: formatReading(snapshot.rpm, suffix: "", digits: 0), icon: "gauge.with.dots.needle.50percent") }
                    if snapshot.coolantF != nil { MetricCard(title: "Coolant", value: formatReading(snapshot.coolantF, suffix: "°F"), icon: "thermometer.medium") }
                    if snapshot.speedMph != nil { MetricCard(title: "Speed", value: formatReading(snapshot.speedMph, suffix: " mph", digits: 0), icon: "speedometer") }
                    if snapshot.voltage != nil { MetricCard(title: "Battery", value: formatReading(snapshot.voltage, suffix: " V", digits: 1), icon: "bolt.fill") }
                }
            }
        }
    }

    private var hasMetrics: Bool { snapshot.rpm != nil || snapshot.coolantF != nil || snapshot.speedMph != nil || snapshot.voltage != nil }
    private var connectionColor: Color {
        if demoMode { return SDTheme.amber }
        if case .failed = obd.state { return SDTheme.red }
        return connected ? SDTheme.green : SDTheme.muted
    }
    private var connectionLabel: String {
        if demoMode { return "DEMO" }
        if case .failed = obd.state { return "FAILED" }
        return connected ? "CONNECTED" : "OFFLINE"
    }
}
