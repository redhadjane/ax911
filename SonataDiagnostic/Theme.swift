import Foundation
import SwiftUI

enum SDTheme {
    static let background = Color(red: 0.012, green: 0.020, blue: 0.024)
    static let panel = Color(red: 0.038, green: 0.055, blue: 0.061)
    static let panelRaised = Color(red: 0.060, green: 0.080, blue: 0.087)
    static let border = Color.white.opacity(0.085)
    static let borderBright = Color.white.opacity(0.15)
    static let muted = Color(red: 0.56, green: 0.61, blue: 0.63)
    static let tertiary = Color(red: 0.36, green: 0.42, blue: 0.44)
    static let green = Color(red: 0.22, green: 0.91, blue: 0.49)
    static let cyan = Color(red: 0.23, green: 0.78, blue: 0.91)
    static let amber = Color(red: 1.00, green: 0.61, blue: 0.18)
    static let red = Color(red: 1.00, green: 0.32, blue: 0.38)
}

struct AppBackdrop: View {
    var body: some View {
        ZStack {
            SDTheme.background
            RadialGradient(colors: [SDTheme.green.opacity(0.10), .clear], center: UnitPoint(x: 0.82, y: 0.08), startRadius: 0, endRadius: 290)
            RadialGradient(colors: [SDTheme.cyan.opacity(0.055), .clear], center: UnitPoint(x: 0.05, y: 0.68), startRadius: 0, endRadius: 340)
            LinearGradient(colors: [.clear, Color.black.opacity(0.18)], startPoint: .top, endPoint: .bottom)
        }
    }
}

struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(.white).tracking(-0.4)
            if let subtitle {
                Text(subtitle).font(.system(size: 13.5, weight: .regular)).foregroundStyle(SDTheme.muted).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 10.5, weight: .bold)).tracking(1.6).foregroundStyle(SDTheme.muted).frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .bold)).tracking(0.35)
            .foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(color.opacity(0.105), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.28), lineWidth: 0.7))
    }
}

private struct PremiumCardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(SDTheme.panel.opacity(0.96))
                    LinearGradient(colors: [Color.white.opacity(0.025), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                }
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(SDTheme.border, lineWidth: 0.8))
    }
}

extension View {
    func premiumCard(padding: CGFloat = 15, radius: CGFloat = 20) -> some View {
        modifier(PremiumCardModifier(padding: padding, radius: radius))
    }
}

struct WhiteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(Color.white.opacity(configuration.isPressed ? 0.76 : 1), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(LinearGradient(colors: [SDTheme.green, Color(red: 0.41, green: 0.96, blue: 0.65)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .shadow(color: SDTheme.green.opacity(configuration.isPressed ? 0.1 : 0.20), radius: 18, y: 7)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

func formatReading(_ value: Double?, suffix: String, digits: Int = 0) -> String {
    guard let value else { return "—" }
    return String(format: "%.*f%@", digits, value, suffix)
}

func signedReading(_ value: Double?, suffix: String) -> String {
    guard let value else { return "—" }
    return String(format: "%+.1f%@", value, suffix)
}
