import SwiftUI
import UIKit

enum AcademyPalette {
    static let forest = Color(red:0.055,green:0.24,blue:0.19)
    static let lime = Color(red:0.82,green:0.90,blue:0.64)
    static let jade = Color(red:0.22,green:0.55,blue:0.39)
    static let amber = Color(red:0.76,green:0.51,blue:0.19)
    static let canvas = Color(uiColor:.systemGroupedBackground)
    static let card = Color(uiColor:.secondarySystemGroupedBackground)
    static let quiet = Color.secondary
}
struct AcademyCard<Content: View>: View {
    var padding: CGFloat = 22
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment:.leading,spacing:16) { content }
            .fixedSize(horizontal:false,vertical:true)
            .padding(padding).frame(maxWidth:.infinity,alignment:.leading)
            .background(AcademyPalette.card,in:RoundedRectangle(cornerRadius:24,style:.continuous))
            .overlay(RoundedRectangle(cornerRadius:24,style:.continuous).strokeBorder(Color.primary.opacity(0.035)))
    }
}
struct Eyebrow: View {
    var text: String; var color: Color = .secondary
    var body: some View { Text(text.uppercased()).font(.system(.caption2,design:.rounded,weight:.bold)).tracking(1.7).foregroundStyle(color) }
}
struct PrimaryAction: View {
    var title: String; var icon = "arrow.right"; var light = false; var action: () -> Void
    var body: some View {
        Button(action:action) { HStack(spacing:10) { Text(title).font(.headline); Spacer(minLength:8); Image(systemName:icon).font(.headline) }.padding(.horizontal,19).padding(.vertical,17).frame(minHeight:54) }
            .buttonStyle(.plain).foregroundStyle(light ? AcademyPalette.forest : Color.white)
            .background(light ? AcademyPalette.lime : AcademyPalette.forest,in:RoundedRectangle(cornerRadius:17,style:.continuous))
    }
}
struct MiniMetric: View {
    let value: String; let label: String; let icon: String
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            Image(systemName:icon).foregroundStyle(AcademyPalette.jade).font(.title3)
            Text(value).font(.system(.title2,design:.rounded,weight:.bold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth:.infinity,alignment:.leading).padding(17).background(AcademyPalette.card,in:RoundedRectangle(cornerRadius:20))
    }
}
struct MasteryRing: View {
    let score: Int?; var size: CGFloat = 110; var light = false
    var body: some View {
        ZStack {
            Circle().stroke((light ? Color.white : Color.primary).opacity(0.10),lineWidth:8)
            if let score { Circle().trim(from:0,to:Double(score)/100).stroke(light ? AcademyPalette.lime : AcademyPalette.jade,style:StrokeStyle(lineWidth:8,lineCap:.round)).rotationEffect(.degrees(-90)) }
            VStack(spacing:0) {
                Text(score.map(String.init) ?? "—").font(.system(size:size * 0.30,weight:.semibold,design:.rounded)).monospacedDigit()
                Text(score == nil ? "START HERE" : "MASTERY %").font(.system(size:8,weight:.bold)).tracking(1)
            }.foregroundStyle(light ? .white : .primary)
        }.frame(width:size,height:size).accessibilityElement(children:.ignore).accessibilityLabel(score.map { "Mastery estimate \($0) percent" } ?? "Mastery not assessed")
    }
}
struct ChapterRow: View {
    var chapter: ChapterEvidence; var action: () -> Void
    var body: some View {
        Button(action:action) {
            HStack(spacing:15) {
                Image(systemName:AcademyEngine.chapterIcons[chapter.id-1]).font(.title3).frame(width:43,height:43).background(AcademyPalette.jade.opacity(0.10),in:RoundedRectangle(cornerRadius:13)).foregroundStyle(AcademyPalette.jade)
                VStack(alignment:.leading,spacing:7) {
                    HStack { Text(chapter.name).font(.subheadline.weight(.semibold)); Spacer(); Text(chapter.score.map { "\($0)%" } ?? "—").font(.subheadline.weight(.semibold)).monospacedDigit() }
                    ProgressView(value:Double(chapter.score ?? 0),total:100).tint(AcademyPalette.jade)
                    Text("\(chapter.assessed) of \(chapter.total) objectives assessed").font(.caption2).foregroundStyle(.secondary)
                }
                Image(systemName:"chevron.right").font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
            }.padding(.vertical,7).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
struct SectionTitle: View {
    var title: String; var subtitle: String?
    var body: some View { VStack(alignment:.leading,spacing:5) { Text(title).font(.title3.weight(.bold)); if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) } } }
}
struct PageLayout<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:22) { content }.padding(.horizontal,20).padding(.top,12).padding(.bottom,32).frame(maxWidth:1060).frame(maxWidth:.infinity) }.background(AcademyPalette.canvas)
    }
}
func academyHaptic(_ kind: UINotificationFeedbackGenerator.FeedbackType = .success) {
    guard UserDefaults.standard.object(forKey:"academy.haptics") as? Bool ?? true else { return }
    UINotificationFeedbackGenerator().notificationOccurred(kind)
}
