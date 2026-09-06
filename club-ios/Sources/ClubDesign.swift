import SwiftUI
import UIKit

// Presentation-only system. Customer balances, pricing and permissions remain server-owned.
enum ClubStyle {
    static let green=Color(red:15/255,green:91/255,blue:76/255)
    static let teal=Color(red:11/255,green:122/255,blue:99/255)
    static let red=Color(red:211/255,green:49/255,blue:49/255)
    static let cream=Color(red:245/255,green:242/255,blue:234/255)
    static let gold=Color(red:226/255,green:196/255,blue:137/255)
    static let accent=Color(uiColor:UIColor { $0.userInterfaceStyle == .dark ? UIColor(red:0.43,green:0.84,blue:0.71,alpha:1) : UIColor(red:15/255,green:91/255,blue:76/255,alpha:1) })
    static let surface=Color(uiColor:UIColor { $0.userInterfaceStyle == .dark ? UIColor(red:0.09,green:0.15,blue:0.14,alpha:1) : .white })
    static func touch() {if UserDefaults.standard.object(forKey:"hop.club.haptics") as? Bool != false {UISelectionFeedbackGenerator().selectionChanged()}}
}
struct ClubBackground:View {
    @Environment(\.colorScheme) var scheme
    var body:some View {LinearGradient(colors:scheme == .dark ? [Color(red:0.055,green:0.10,blue:0.09),Color(red:0.075,green:0.12,blue:0.11)] : [Color(red:0.99,green:0.98,blue:0.95),ClubStyle.cream],startPoint:.topLeading,endPoint:.bottomTrailing).ignoresSafeArea()}
}
struct ClubPanel<Content:View>:View {
    @ViewBuilder var content:Content
    var body:some View {VStack(alignment:.leading,spacing:16){content}.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(ClubStyle.surface,in:RoundedRectangle(cornerRadius:26,style:.continuous)).overlay(RoundedRectangle(cornerRadius:26).stroke(.primary.opacity(0.055),lineWidth:1)).shadow(color:.black.opacity(0.025),radius:12,x:0,y:6)}
}
struct ClubPage<Content:View>:View {
    @EnvironmentObject var store:ClubStore
    @ViewBuilder var content:Content
    var body:some View {ScrollView {VStack(alignment:.leading,spacing:24){content}.padding(.horizontal,20).padding(.top,16).padding(.bottom,28).frame(maxWidth:680).frame(maxWidth:.infinity)}.background(ClubBackground()).refreshable {await store.refresh()}.scrollDismissesKeyboard(.interactively)}
}
struct ClubPill:View {
    var title:String;var color:Color=ClubStyle.accent
    var body:some View {Text(title.replacingOccurrences(of:"_",with:" ").capitalized).font(.caption.weight(.semibold)).padding(.horizontal,11).padding(.vertical,7).foregroundStyle(color).background(color.opacity(0.10),in:Capsule()).fixedSize(horizontal:false,vertical:true)}
}
struct ClubPhoto:View {
    var path:String;var height:CGFloat=150
    var body:some View {GeometryReader {g in AsyncImage(url:ClubPolicy.media(path)){phase in
        if let image=phase.image {image.resizable().scaledToFill()}
        else {ZStack {LinearGradient(colors:[ClubStyle.green.opacity(0.15),ClubStyle.gold.opacity(0.15)],startPoint:.topLeading,endPoint:.bottomTrailing);VStack(spacing:8){Image(systemName:"fork.knife").font(.system(size:30,weight:.light));Text("HOUSE OF PIZZA").font(.system(size:9,weight:.bold)).tracking(2)}.foregroundStyle(ClubStyle.accent.opacity(0.65))}}
    }.frame(width:g.size.width,height:g.size.height).clipped()}.frame(height:height).clipShape(RoundedRectangle(cornerRadius:20,style:.continuous)).accessibilityHidden(true)}
}
struct ClubPressStyle:ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduced
    func makeBody(configuration:Configuration)->some View {configuration.label.opacity(configuration.isPressed ? 0.78 : 1).scaleEffect(configuration.isPressed && !reduced ? 0.98 : 1).animation(reduced ? nil : .easeOut(duration:0.16),value:configuration.isPressed)}
}
struct ClubAction:View {
    @Environment(\.isEnabled) var enabled
    var title:String;var symbol:String;var action:()->Void
    var body:some View {Button {ClubStyle.touch();action()}label:{HStack(spacing:12){Text(title);Spacer(minLength:8);Image(systemName:symbol)}.font(.headline).padding(.horizontal,20).padding(.vertical,18).frame(maxWidth:.infinity).foregroundStyle(.white).background(enabled ? ClubStyle.green : Color.secondary.opacity(0.45),in:RoundedRectangle(cornerRadius:19,style:.continuous))}.buttonStyle(ClubPressStyle())}
}
struct ClubHeading:View {
    var eyebrow:String;var title:String;var subtitle:String=""
    var body:some View {VStack(alignment:.leading,spacing:9){Text(eyebrow.uppercased()).font(.caption2.weight(.bold)).tracking(2.5).foregroundStyle(ClubStyle.accent);Text(title).font(.system(.largeTitle,design:.rounded,weight:.bold)).tracking(-1);if !subtitle.isEmpty {Text(subtitle).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)}}
}
struct ClubSectionTitle:View {
    var title:String;var detail:String=""
    var body:some View {HStack(alignment:.firstTextBaseline){Text(title).font(.title3.bold());Spacer();if !detail.isEmpty {Text(detail).font(.caption).foregroundStyle(.secondary)}}}
}
struct ClubIcon:View {
    var symbol:String;var color:Color=ClubStyle.accent
    var body:some View {Image(systemName:symbol).font(.system(size:19,weight:.semibold)).foregroundStyle(color).frame(width:46,height:46).background(color.opacity(0.09),in:RoundedRectangle(cornerRadius:15))}
}
struct ClubLinkRow:View {
    var symbol:String;var title:String;var subtitle:String=""
    var chevron=true
    var body:some View {HStack(spacing:14){ClubIcon(symbol:symbol);VStack(alignment:.leading,spacing:4){Text(title).font(.headline).foregroundStyle(.primary);if !subtitle.isEmpty {Text(subtitle).font(.caption).foregroundStyle(.secondary)}};Spacer(minLength:8);if chevron {Image(systemName:"chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)}}.frame(minHeight:48).contentShape(Rectangle())}
}
struct ClubVisitTrack:View {
    var progress:Int;var goal:Int
    var body:some View {VStack(alignment:.leading,spacing:14){
        if goal>0 && goal<=20 {LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:9),count:min(goal,5)),spacing:9){ForEach(0..<goal,id:\.self){index in Image(systemName:index<progress ? "checkmark" : "sparkle").font(.system(size:16,weight:.semibold)).frame(maxWidth:.infinity).frame(height:40).foregroundStyle(index<progress ? .white : ClubStyle.accent.opacity(0.4)).background(index<progress ? ClubStyle.green : ClubStyle.accent.opacity(0.07),in:RoundedRectangle(cornerRadius:12))}}.accessibilityElement(children:.ignore).accessibilityLabel("\(progress) of \(goal) visits")}
        else {ProgressView(value:Double(max(0,min(progress,goal))),total:Double(max(1,goal))).tint(ClubStyle.accent)}
    }}
}
struct ClubSheetClose:View {
    @Environment(\.dismiss) var dismiss
    var body:some View {Button {dismiss()}label:{Image(systemName:"xmark").font(.system(size:13,weight:.bold)).foregroundStyle(.secondary).frame(width:36,height:36).background(.secondary.opacity(0.1),in:Circle())}.accessibilityLabel("Close")}
}
