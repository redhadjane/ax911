import SwiftUI

struct AppTopBar: View {
    let title: String
    let demoMode: Bool
    let onMenu: () -> Void
    let onVehicle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onMenu) {
                Image(systemName: "line.3.horizontal").font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44)
            }
            Spacer(minLength: 0)
            VStack(spacing: 3) {
                HStack(spacing: 7) {
                    Text(title).font(.system(size: 16, weight: .bold, design: .rounded)).lineLimit(1)
                    if demoMode { StatusBadge(text: "DEMO", color: SDTheme.amber) }
                }
                HStack(spacing: 5) {
                    Circle().fill(SDTheme.green).frame(width: 5, height: 5).shadow(color: SDTheme.green, radius: 4)
                    Text("OBDLink CX  ·  Connected").font(.system(size: 10.5, weight: .medium)).foregroundStyle(SDTheme.muted)
                }
            }
            Spacer(minLength: 0)
            Button(action: onVehicle) {
                Image(systemName: "car.fill").font(.system(size: 17, weight: .semibold)).frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .frame(height: 58)
        .background(SDTheme.background.opacity(0.94))
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
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Color.black.opacity(0.72).contentShape(Rectangle()).onTapGesture(perform: onClose)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 12).fill(SDTheme.green.opacity(0.12)).frame(width: 42, height: 42)
                            .overlay(Image(systemName: "waveform.path.ecg").foregroundStyle(SDTheme.green))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SONATA").font(.system(size: 17, weight: .bold, design: .rounded)).tracking(0.5)
                            Text("DIAGNOSTIC").font(.system(size: 10, weight: .medium)).tracking(1.4).foregroundStyle(SDTheme.muted)
                        }
                        Spacer()
                        Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).frame(width: 40, height: 40).background(Color.white.opacity(0.055), in: Circle()) }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 15)

                    Rectangle().fill(SDTheme.border).frame(height: 0.7)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 1) {
                            ForEach(AppRoute.menuRoutes) { item in
                                Button {
                                    route = item
                                    onClose()
                                } label: {
                                    HStack(spacing: 13) {
                                        Image(systemName: item.icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(route == item ? SDTheme.green : SDTheme.muted).frame(width: 24)
                                        Text(item.menuTitle).font(.system(size: 14.5, weight: route == item ? .semibold : .medium))
                                        Spacer()
                                        if route == item { Circle().fill(SDTheme.green).frame(width: 5, height: 5) }
                                    }
                                    .foregroundStyle(.white).padding(.horizontal, 16).frame(height: 43)
                                    .background(route == item ? SDTheme.green.opacity(0.075) : .clear, in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8).padding(.top, 8)

                        if demoMode {
                            VStack(alignment: .leading, spacing: 9) {
                                SectionLabel(text: "Demo scenario")
                                Picker("Demo scenario", selection: $scenario) {
                                    ForEach(DemoScenario.allCases) { item in Text(item.rawValue).tag(item) }
                                }
                                .tint(.white).pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12).frame(height: 44)
                                .background(SDTheme.panelRaised, in: RoundedRectangle(cornerRadius: 13))
                            }.padding(.horizontal, 16).padding(.top, 18)
                        }

                        Button(action: onDisconnect) {
                            Label(demoMode ? "Exit Demo" : "Disconnect", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 14.5, weight: .semibold)).foregroundStyle(SDTheme.red).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 18).frame(height: 48)
                        }.buttonStyle(.plain).padding(.top, 6)

                        Text(demoMode ? "Preview data is simulated and always labeled." : "Vehicle data remains on this iPhone.")
                            .font(.system(size: 11)).foregroundStyle(SDTheme.muted).padding(.horizontal, 18).padding(.bottom, 24)
                    }
                }
                .frame(width: min(proxy.size.width - 44, 336), height: proxy.size.height)
                .background(AppBackdrop())
                .overlay(alignment: .trailing) { Rectangle().fill(SDTheme.borderBright).frame(width: 0.7) }
                .shadow(color: .black.opacity(0.45), radius: 30, x: 12)
            }
        }
    }
}

struct ScanProgressOverlay: View {
    let progress: Int
    let message: String

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.76)
            VStack(alignment: .leading, spacing: 16) {
                Capsule().fill(Color.white.opacity(0.16)).frame(width: 42, height: 4).frame(maxWidth: .infinity)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Intelligent vehicle scan").font(.system(size: 21, weight: .bold, design: .rounded))
                        Text("Reading only what your Sonata reports.").font(.system(size: 13)).foregroundStyle(SDTheme.muted)
                    }
                    Spacer()
                    ZStack { Circle().stroke(SDTheme.border, lineWidth: 4); Circle().trim(from: 0, to: Double(progress) / 100).stroke(SDTheme.green, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90)); Text("\(progress)").font(.system(size: 12, weight: .bold).monospacedDigit()) }.frame(width: 52, height: 52)
                }
                ProgressView(value: Double(progress), total: 100).tint(SDTheme.green)
                Text(message).font(.system(size: 12.5, weight: .medium)).foregroundStyle(SDTheme.muted).lineLimit(1)
            }
            .padding(20)
            .background(SDTheme.panelRaised, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 27).stroke(SDTheme.borderBright, lineWidth: 0.8))
            .padding(.horizontal, 10).padding(.bottom, 8)
        }
    }
}
