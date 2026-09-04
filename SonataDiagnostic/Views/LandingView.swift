import SwiftUI

struct LandingView: View {
    @EnvironmentObject private var obd: OBDLinkCXManager
    let onStartDemo: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SONATA")
                        .font(.system(size: 46, weight: .bold, design: .rounded)).tracking(0.8)
                    HStack(alignment: .top, spacing: 1) {
                        Text("DIAGNOSTIC").font(.system(size: 31, weight: .light, design: .rounded)).tracking(0.9)
                        Text("°").font(.system(size: 18, weight: .medium)).padding(.top, 1)
                    }
                    Text("Your car. Your data.\nNo subscriptions.")
                        .font(.system(size: 17, weight: .regular)).foregroundStyle(SDTheme.muted)
                        .lineSpacing(4).padding(.top, 25)
                }

                VehicleRenderView(angle: .hero)
                    .frame(maxWidth: .infinity).frame(height: 268)
                    .padding(.top, 6)

                connectionCard
                Button(action: onStartDemo) {
                    Label("Interactive Demo Mode", systemImage: "play.circle.fill")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(SDTheme.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 22).padding(.top, 34).padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SDTheme.background.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
    }

    private var connectionCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 13).fill(SDTheme.green.opacity(0.12)).frame(width: 50, height: 50)
                    .overlay(Image("OBDLinkCX").resizable().scaledToFit().padding(7))
                VStack(alignment: .leading, spacing: 2) {
                    Text("OBDLink CX").font(.system(size: 18, weight: .bold))
                    Text(obd.message == "Disconnected" ? "Ready for Bluetooth LE" : obd.message)
                        .font(.system(size: 13)).foregroundStyle(SDTheme.muted).lineLimit(2)
                }
                Spacer()
            }
            .padding(18)
            Divider().overlay(SDTheme.border)
            VStack(alignment: .leading, spacing: 5) {
                Text("2015 Hyundai Sonata Sport").font(.system(size: 16, weight: .bold))
                Text("VIN: Will be confirmed by OBD/CAN")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(SDTheme.muted)
            }
            .padding(.horizontal, 18).padding(.top, 16)
            Button("Connect") { obd.connect() }
                .buttonStyle(WhiteButtonStyle()).padding(18)

            if case .failed(let reason) = obd.state {
                Text(reason).font(.caption).foregroundStyle(SDTheme.red).padding(.horizontal, 18).padding(.bottom, 16)
            }
        }
        .background(SDTheme.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(SDTheme.border, lineWidth: 1))
    }
}
