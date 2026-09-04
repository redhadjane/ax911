import SwiftUI

struct AppTopBar: View {
    let title: String
    let demoMode: Bool
    let onMenu: () -> Void
    let onVehicle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onMenu) {
                Image(systemName: "line.3.horizontal").font(.system(size: 20, weight: .medium)).frame(width: 38, height: 44)
            }
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.system(size: 16, weight: .bold)).lineLimit(1)
                    if demoMode { StatusBadge(text: "DEMO", color: SDTheme.amber) }
                }
                Text("OBDLink CX · Connected").font(.system(size: 11, weight: .medium)).foregroundStyle(SDTheme.muted)
            }
            Spacer(minLength: 0)
            Button(action: onVehicle) {
                Image(systemName: "car.fill").font(.system(size: 18, weight: .semibold)).frame(width: 38, height: 44)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(height: 65)
        .background(SDTheme.background.opacity(0.98))
        .overlay(alignment: .bottom) { Rectangle().fill(SDTheme.border).frame(height: 0.7) }
    }
}

struct SideMenu: View {
    @Binding var route: AppRoute
    @Binding var scenario: DemoScenario
    let demoMode: Bool
    let onClose: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.68).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Menu").font(.system(size: 24, weight: .bold))
                    Spacer()
                    Button(action: onClose) { Image(systemName: "xmark").frame(width: 42, height: 42) }
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 1) {
                        ForEach(AppRoute.menuRoutes) { item in
                            Button {
                                route = item
                                onClose()
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: item.icon).font(.system(size: 17, weight: .medium)).foregroundStyle(route == item ? SDTheme.green : SDTheme.muted).frame(width: 25)
                                    Text(item.rawValue).font(.system(size: 16, weight: .medium))
                                    Spacer()
                                }
                                .foregroundStyle(.white).padding(.horizontal, 20).frame(height: 48)
                                .background(route == item ? Color.white.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)

                    if demoMode {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(text: "Demo scenario")
                            Picker("Demo scenario", selection: $scenario) {
                                ForEach(DemoScenario.allCases) { item in Text(item.rawValue).tag(item) }
                            }
                            .tint(.white).pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).frame(height: 48)
                            .background(SDTheme.panelRaised, in: RoundedRectangle(cornerRadius: 13))
                        }.padding(20)
                    }

                    Button(action: onDisconnect) {
                        Label(demoMode ? "Exit Demo" : "Disconnect", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(SDTheme.red).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20).frame(height: 52)
                    }.buttonStyle(.plain)

                    Text(demoMode ? "Demo data is simulated and clearly labeled." : "Real vehicle data stays on this iPhone.")
                        .font(.caption).foregroundStyle(SDTheme.muted).padding(.horizontal, 20).padding(.bottom, 24)
                }
            }
            .frame(width: min(UIScreen.main.bounds.width * 0.84, 355))
            .frame(maxHeight: .infinity)
            .background(SDTheme.background)
            .overlay(alignment: .trailing) { Rectangle().fill(SDTheme.border).frame(width: 1) }
        }
    }
}

struct ScanProgressOverlay: View {
    let progress: Int
    let message: String

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Capsule().fill(Color.white.opacity(0.18)).frame(width: 46, height: 5).frame(maxWidth: .infinity)
                Text("Scanning your Sonata").font(.system(size: 24, weight: .bold))
                Text("OBD/CAN responses decide which modules and features appear.").font(.system(size: 14)).foregroundStyle(SDTheme.muted)
                ProgressView(value: Double(progress), total: 100).tint(SDTheme.green)
                HStack { Text(message).lineLimit(1); Spacer(); Text("\(progress)%").foregroundStyle(SDTheme.green) }.font(.system(size: 13)).foregroundStyle(SDTheme.muted)
            }
            .padding(22).padding(.bottom, 10)
            .background(SDTheme.panel, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(SDTheme.border, lineWidth: 1))
            .padding(.horizontal, 12).padding(.bottom, 8)
        }
    }
}
