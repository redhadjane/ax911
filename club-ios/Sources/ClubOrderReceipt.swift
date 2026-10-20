import SwiftUI

struct ClubOrderReceipt: View {
    let order:J
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduced
    @State private var arrived=false
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:24) {
                    ZStack {Circle().fill(ClubStyle.accent.opacity(0.10)).frame(width:140,height:140);Image(systemName:"checkmark.seal.fill").font(.system(size:74,weight:.light)).foregroundStyle(ClubStyle.accent).scaleEffect(arrived ? 1 : 0.7)}.frame(maxWidth:.infinity).padding(.top,30)
                    ClubHeading(eyebrow:"REQUEST RECEIVED",title:"You're on our list.",subtitle:"HOP has received your pickup request. You're not charged in the app.")
                    ClubPanel {
                        Label("Next: a host confirms by phone",systemImage:"phone.badge.checkmark").font(.headline)
                        Text("Please wait for the restaurant to confirm before expecting kitchen preparation or a pickup time.").font(.subheadline).foregroundStyle(.secondary)
                        Divider()
                        Label("Then: prepare your order",systemImage:"flame").foregroundStyle(.secondary)
                        Label("Finally: pick up & pay at HOP",systemImage:"takeoutbag.and.cup.and.straw").foregroundStyle(.secondary)
                    }
                    ClubPanel {Text("Request #"+String(order.id.replacingOccurrences(of:"-",with:"").prefix(8)).uppercased()).font(.headline);HStack {Text("Quoted total");Spacer();Text(ClubPolicy.money(order["total"].number)).fontWeight(.semibold)};Text("Follow status in You → Orders & pickup.").font(.caption).foregroundStyle(.secondary)}
                    ClubAction(title:"Keep exploring",symbol:"arrow.right") { dismiss() }
                }.padding(24)
            }.background(ClubBackground()).navigationTitle("Sent to HOP").navigationBarTitleDisplayMode(.inline).toolbar {ToolbarItem(placement:.topBarTrailing){ClubSheetClose()}}
                .onAppear {withAnimation(reduced ? nil : .spring(response:0.55,dampingFraction:0.65)){arrived=true}}
        }
    }
}
