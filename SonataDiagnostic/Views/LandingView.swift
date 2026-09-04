import SwiftUI

struct LandingView: View {
    @EnvironmentObject private var obd: OBDLinkCXManager
    let onStartDemo: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 7) {
                        Circle().fill(SDTheme.green).frame(width: 7, height: 7).shadow(color: SDTheme.green, radius: 7)
                        Text("PRIVATE · ON DEVICE").font(.system(size: 10, weight: .bold)).tracking(1.35).foregroundStyle(SDTheme.muted)
                    }
                    Spacer()
                    Text("2026").font(.system(size: 10, weight: .bold).monospacedDigit()).foregroundStyle(SDTheme.green).padding(.horizontal, 9).padding(.vertical, 5).background(SDTheme.green.opacity(0.09), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("SONATA").font(.system(size: 42, weight: .bold, design: .rounded)).tracking(0.5)
                    HStack(alignment: .top, spacing: 1) {
                        Text("DIAGNOSTIC").font(.system(size: 28, weight: .light, design: .rounded)).tracking(0.8)
                        Text("°").font(.system(size: 16, weight: .medium)).padding(.top, 1)
                    }
                    Text("Your car, translated.").font(.system(size: 16, weight: .medium)).foregroundStyle(.white.opacity(0.92)).padding(.top, 14)
                    Text("Private diagnostics. Clear answers. No subscription.").font(.system(size: 12.5)).foregroundStyle(SDTheme.muted).padding(.top, 2)
                }.padding(.top, 27)

                ZStack {
                    Ellipse().fill(SDTheme.green.opacity(0.055)).frame(width: 310, height: 100).blur(radius: 24).offset(y: 34)
                    Ellipse().stroke(SDTheme.green.opacity(0.10), lineWidth: 0.7).frame(width: 330, height: 126).offset(y: 34)
                    VehicleRenderView(angle: .hero).frame(maxWidth: .infinity).frame(height: 210)
                }.frame(maxWidth: .infinity).frame(height: 214)

                connectionCard
                Button(action: onStartDemo) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").foregroundStyle(SDTheme.green)
                        Text("Explore the interactive demo").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundStyle(SDTheme.muted)
                    }.frame(maxWidth: .infinity).frame(height: 48)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }

    private var connectionCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 13).fill(SDTheme.green.opacity(0.11)).frame(width: 48, height: 48)
                    .overlay(Image("OBDLinkCX").resizable().scaledToFit().padding(8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("OBDLink CX").font(.system(size: 16, weight: .bold))
                    Text(obd.message == "Disconnected" ? "Ready for Bluetooth LE" : obd.message)
                        .font(.system(size: 12)).foregroundStyle(SDTheme.muted).lineLimit(2)
                }
                Spacer()
                Circle().fill(SDTheme.green).frame(width: 7, height: 7).shadow(color: SDTheme.green.opacity(0.7), radius: 6)
            }
            .padding(15)
            Divider().overlay(SDTheme.border)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("2015 Hyundai Sonata Sport").font(.system(size: 14.5, weight: .semibold))
                    Text("Identity confirmed after the first read-only scan")
                        .font(.system(size: 11.5)).foregroundStyle(SDTheme.muted)
                }
                Spacer()
                Image(systemName: "lock.shield.fill").font(.system(size: 15)).foregroundStyle(SDTheme.green)
            }
            .padding(.horizontal, 15).padding(.top, 14)
            Button("Connect securely") { obd.connect() }
                .buttonStyle(GlowButtonStyle()).padding(15)

            if case .failed(let reason) = obd.state {
                Text(reason).font(.system(size: 11.5)).foregroundStyle(SDTheme.red).padding(.horizontal, 15).padding(.bottom, 14)
            }
        }
        .background(SDTheme.panel.opacity(0.94), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(SDTheme.borderBright, lineWidth: 0.8))
        .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
    }
}
