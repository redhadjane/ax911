import SwiftUI

struct ClubDishArt: View {
    let item:J
    var selections:[String:[J]] = [:]
    var height:CGFloat=185
    var body:some View {
        Group {
            if ClubPolicy.media(item["image_url"].text) != nil {ClubPhoto(path:item["image_url"].text,height:height)}
            else if ClubBuilder.isPizza(item) {
                ClubPizzaArt(layers:ClubBuilder.layers(item,selections:selections)).padding(6).frame(maxWidth:.infinity).background(ClubStyle.gold.opacity(0.08))
                    .overlay(alignment:.bottomTrailing){Text("Illustration").font(.caption2).foregroundStyle(.secondary).padding(9)}
            } else {ClubPhoto(path:"",height:height)}
        }
    }
}

// Original HOP illustration. No competitor artwork; not a recipe photograph.
struct ClubIngredientArt: View {
    let kind: ClubIngredient
    var body: some View { Canvas { context, size in drawIngredient(kind, context:&context, center:CGPoint(x:size.width/2,y:size.height/2), radius:min(size.width,size.height)*0.32) }.accessibilityHidden(true) }
}
struct ClubPizzaArt: View {
    let layers: [ClubToppingLayer]
    var sauce = ""
    var thin = false
    @Environment(\.accessibilityReduceMotion) private var reduced
    private var cheeseColors:[Color] { sauce.lowercased().contains("alfredo") ? [Color(red:1,green:0.95,blue:0.77),Color(red:0.86,green:0.72,blue:0.41)] : [Color(red:1,green:0.86,blue:0.43),Color(red:0.94,green:0.67,blue:0.24)] }
    private var animationKey:[String] { layers.map { [$0.id,$0.portion,$0.style,String($0.quantity)].joined(separator:"|") } }
    private var spokenLabel:String { "Pizza illustration. " + (layers.isEmpty ? "No selected additions." : layers.map { [$0.name,$0.portion,$0.style].joined(separator:", ") }.joined(separator:". ")) }
    var body: some View {
        ZStack {
            base
            bakedCheese
            ForEach(layers) { layer in ClubToppingCanvas(layer:layer).padding(31).transition(.scale(scale:0.85).combined(with:.opacity)) }
        }.aspectRatio(1,contentMode:.fit).animation(reduced ? nil : .spring(response:0.35,dampingFraction:0.78),value:animationKey)
            .accessibilityElement(children:.ignore).accessibilityLabel(spokenLabel)
    }
    private var base:some View {
        ZStack {
            Circle().fill(ClubStyle.gold.opacity(0.10)).padding(2)
            Circle().fill(Color.black.opacity(0.1)).padding(18).blur(radius:12).offset(y:14)
            Circle().fill(RadialGradient(colors:[Color(red:0.94,green:0.70,blue:0.32),Color(red:0.63,green:0.30,blue:0.09)],center:.center,startRadius:70,endRadius:145)).padding(thin ? 13 : 10)
            Circle().fill(Color(red:0.68,green:0.18,blue:0.08)).padding(thin ? 22 : 28)
            Circle().fill(RadialGradient(colors:cheeseColors,center:.topLeading,startRadius:10,endRadius:250)).padding(thin ? 27 : 33)
        }
    }
    private var bakedCheese:some View {
        Canvas { context, size in
            let center = CGPoint(x:size.width/2,y:size.height/2)
            let radius = min(size.width,size.height)/2
            for point in ClubBuilder.positions(seed:"baked-cheese",portion:"whole",count:45) {
                let spot = CGRect(x:center.x+CGFloat(point.0)*radius-2,y:center.y+CGFloat(point.1)*radius-2,width:5,height:3)
                context.fill(Path(ellipseIn:spot),with:.color(Color(red:0.57,green:0.28,blue:0.08).opacity(0.28)))
            }
        }.padding(34)
    }
}
private struct ClubToppingCanvas:View {
    let layer:ClubToppingLayer
    var body:some View { Canvas { context, size in
        let center=CGPoint(x:size.width/2,y:size.height/2)
        let radius=min(size.width,size.height)/2
        let factor:Int=layer.style == "extra" ? 19 : layer.style == "light" ? 7 : 12
        let count=min(36,factor*min(2,layer.quantity))
        for point in ClubBuilder.positions(seed:layer.id,portion:layer.portion,count:count) {
            let location=CGPoint(x:center.x+CGFloat(point.0)*radius,y:center.y+CGFloat(point.1)*radius)
            drawIngredient(layer.kind,context:&context,center:location,radius:radius*0.085)
        }
    } }
}
private func drawIngredient(_ kind: ClubIngredient, context: inout GraphicsContext, center: CGPoint, radius r: CGFloat) {
    func ellipse(_ dx:CGFloat,_ dy:CGFloat,_ w:CGFloat,_ h:CGFloat)->Path { Path(ellipseIn:CGRect(x:center.x+dx*r,y:center.y+dy*r,width:w*r,height:h*r)) }
    let meat=Color(red:0.70,green:0.16,blue:0.10), green=Color(red:0.19,green:0.42,blue:0.12)
    switch kind {
    case .pepperoni,.salami:
        context.fill(ellipse(-1,-1,2,2),with:.color(Color(red:0.47,green:0.08,blue:0.04)))
        context.fill(ellipse(-0.86,-0.92,1.72,1.72),with:.color(meat))
        for (x,y) in [(-0.45,-0.35),(0.16,0.05),(-0.1,0.48),(0.40,-0.4)] { context.fill(ellipse(x,y,0.23,0.18),with:.color(Color(red:1,green:0.68,blue:0.39).opacity(0.7))) }
    case .olive,.greenOlive:
        context.stroke(ellipse(-0.76,-0.66,1.52,1.32),with:.color(kind == .olive ? Color(red:0.17,green:0.15,blue:0.11) : Color(red:0.39,green:0.45,blue:0.13)),lineWidth:r*0.45)
    case .mushroom:
        var cap=Path();cap.move(to:CGPoint(x:center.x-r,y:center.y));cap.addQuadCurve(to:CGPoint(x:center.x+r,y:center.y),control:CGPoint(x:center.x,y:center.y-r*1.9));cap.closeSubpath()
        context.fill(Path(roundedRect:CGRect(x:center.x-r*0.25,y:center.y-r*0.1,width:r*0.5,height:r),cornerRadius:r*0.15),with:.color(Color(red:0.85,green:0.77,blue:0.60)))
        context.fill(cap,with:.color(Color(red:0.61,green:0.44,blue:0.29)))
    case .pepper,.bananaPepper,.jalapeno,.onion:
        let color:Color = kind == .onion ? Color(red:0.68,green:0.39,blue:0.58) : kind == .bananaPepper ? Color(red:0.98,green:0.78,blue:0.13) : green
        var arc=Path();arc.addArc(center:center,radius:r*0.75,startAngle:.degrees(20),endAngle:.degrees(310),clockwise:false)
        context.stroke(arc,with:.color(color),style:StrokeStyle(lineWidth:r*0.38,lineCap:.round))
    case .pineapple,.cheese:
        context.fill(Path(roundedRect:CGRect(x:center.x-r*0.7,y:center.y-r*0.55,width:r*1.4,height:r*1.1),cornerRadius:r*0.2),with:.color(Color(red:1,green:0.81,blue:0.22)))
    case .broccoli,.spinach:
        for (x,y) in [(-0.7,-0.3),(0.0,-0.65),(0.15,0.0)] { context.fill(ellipse(x,y,1.1,1.1),with:.color(green)) }
    case .tomato:
        context.fill(ellipse(-0.85,-0.65,1.7,1.3),with:.color(meat));context.stroke(ellipse(-0.55,-0.4,1.1,0.8),with:.color(.orange.opacity(0.7)),lineWidth:r*0.16)
    default:
        let color:Color = [.chicken,.shrimp].contains(kind) ? Color(red:0.92,green:0.68,blue:0.40) : kind == .ham ? Color(red:0.85,green:0.43,blue:0.37) : Color(red:0.43,green:0.26,blue:0.13)
        context.fill(Path(roundedRect:CGRect(x:center.x-r*0.8,y:center.y-r*0.5,width:r*1.6,height:r),cornerRadius:r*0.35),with:.color(color))
        context.fill(ellipse(-0.5,-0.3,0.7,0.3),with:.color(.white.opacity(0.18)))
    }
}
struct ClubBagCelebration: View {
    let name: String
    @Environment(\.accessibilityReduceMotion) private var reduced
    @State private var settled=false
    var body: some View {
        VStack(spacing:18) {
            ZStack {
                Circle().fill(ClubStyle.accent.opacity(0.08)).frame(width:160,height:160)
                Image(systemName:"bag.fill").font(.system(size:74,weight:.light)).foregroundStyle(ClubStyle.green)
                Image(systemName:"checkmark.circle.fill").font(.system(size:36)).foregroundStyle(ClubStyle.accent).background(ClubStyle.surface,in:Circle()).offset(x:42,y:35).scaleEffect(settled ? 1 : 0.5)
            }.offset(y:settled || reduced ? 0 : -20)
            Text("In your bag.").font(.largeTitle.bold())
            Text(name).font(.headline).multilineTextAlignment(.center)
            Text("Made your way. Ready to review.").font(.subheadline).foregroundStyle(.secondary)
        }.padding(30).frame(maxWidth:.infinity,maxHeight:.infinity).background(ClubBackground())
            .onAppear { withAnimation(reduced ? nil : .spring(response:0.5,dampingFraction:0.58)) { settled=true } }
            .accessibilityElement(children:.combine)
    }
}
