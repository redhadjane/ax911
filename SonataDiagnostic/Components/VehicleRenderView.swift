import SwiftUI

struct VehicleRenderView: View {
    enum Angle { case hero, top }
    let angle: Angle
    var body: some View {
        Image(angle == .hero ? "SonataHero" : "SonataTop").resizable().scaledToFit().accessibilityLabel(angle == .hero ? "Graphite Hyundai Sonata" : "Hyundai Sonata viewed from above")
    }
}
