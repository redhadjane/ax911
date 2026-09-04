import Foundation
import SwiftUI

enum SDTheme {
    static let background = Color(red: 0.018, green: 0.022, blue: 0.025)
    static let panel = Color(red: 0.055, green: 0.062, blue: 0.066)
    static let panelRaised = Color(red: 0.075, green: 0.082, blue: 0.087)
    static let border = Color.white.opacity(0.09)
    static let muted = Color(red: 0.55, green: 0.57, blue: 0.59)
    static let green = Color(red: 0.25, green: 0.90, blue: 0.50)
    static let amber = Color(red: 1.00, green: 0.61, blue: 0.16)
    static let red = Color(red: 0.98, green: 0.29, blue: 0.29)
}

struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 27, weight: .semibold, design: .rounded)).foregroundStyle(.white)
            if let subtitle { Text(subtitle).font(.system(size: 15, weight: .regular)).foregroundStyle(SDTheme.muted) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 12, weight: .bold)).tracking(1.5).foregroundStyle(SDTheme.muted).frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text).font(.system(size: 11, weight: .semibold)).foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 6).background(color.opacity(0.11), in: Capsule()).overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 0.7))
    }
}

private struct PremiumCardModifier: ViewModifier {
    var padding: CGFloat
    func body(content: Content) -> some View {
        content.padding(padding).background(SDTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(SDTheme.border, lineWidth: 0.7))
    }
}

extension View {
    func premiumCard(padding: CGFloat = 16) -> some View { modifier(PremiumCardModifier(padding: padding)) }
}

struct WhiteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 17, weight: .semibold)).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 16).background(Color.white.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

func formatReading(_ value: Double?, suffix: String, digits: Int = 0) -> String {
    guard let value else { return "Not available" }
    return String(format: "%.*f%@", digits, value, suffix)
}

func signedReading(_ value: Double?, suffix: String) -> String {
    guard let value else { return "Not available" }
    return String(format: "%+.1f%@", value, suffix)
}
