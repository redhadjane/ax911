import SwiftUI
import PhotosUI

// Keep the user's in-progress decimal text; format only after leaving the field.
struct NativeNumberField:View {
    var placeholder:String; @Binding var value:String
    @State private var input=""; @FocusState private var focused:Bool
    init(_ placeholder:String,text:Binding<String>) {self.placeholder=placeholder;self._value=text}
    var body:some View {TextField(placeholder,text:$input).focused($focused)
        .onAppear {input=value}
        .onChange(of:input){_,text in if focused {value=text}}
        .onChange(of:value){_,text in if !focused {input=text}}
        .onChange(of:focused){_,active in if !active {input=value}}
    }
}

struct NativeField:Identifiable {
    var key:String; var title:String; var kind:Kind = .text
    enum Kind { case text,paragraph,number,date,toggle,choice([String]),money,percent }
    var id:String { key }
}
struct RecordFields:View {
    @Binding var record:J
    var fields:[NativeField]
    func text(_ key:String) -> Binding<String> { Binding(get:{record[key].text},set:{record[key] = .s($0)}) }
    var body:some View { ForEach(fields) { field in
        switch field.kind {
        case .toggle: Toggle(field.title,isOn:Binding(get:{record[field.key].truth},set:{record[field.key] = .bool($0)}))
        case .choice(let choices): Picker(field.title,selection:text(field.key)) { ForEach(choices,id:\.self) { Text($0.replacingOccurrences(of:"_",with:" ").capitalized).tag($0) } }
        case .paragraph: VStack(alignment:.leading) { Text(field.title).font(.subheadline).foregroundStyle(.secondary); TextEditor(text:text(field.key)).frame(minHeight:90) }
        case .date: DatePicker(field.title,selection:Binding(get:{HOPDay.parse(record[field.key].text) ?? Date()},set:{record[field.key] = .s(HOPDay.iso($0))}),displayedComponents:.date).environment(\.timeZone,HOPDay.calendar.timeZone)
        case .money,.percent: LabeledContent(field.title) { NativeNumberField("0.00",text:Binding(get:{HOPMoney.dollars(record[field.key].int)},set:{record[field.key] = .n(HOPMoney.cents($0))})).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth:160) }
        case .number: LabeledContent(field.title) { NativeNumberField("0",text:Binding(get:{record[field.key].text},set:{record[field.key] = .number(Double($0) ?? 0)})).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth:160) }
        case .text: LabeledContent(field.title) { TextField(field.title,text:text(field.key)).multilineTextAlignment(.trailing) }
        }
    } }
}
struct NativeRecordEditor:View {
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) var dismiss
    @State var record:J
    let title:String; let path:String; var method="POST"; let fields:[NativeField]
    var required:[String]=[]
    var body:some View { NavigationStack { Form {
        Section { RecordFields(record:$record,fields:fields) }
        Section { Label("Changes save to your existing HOP database.",systemImage:"lock.shield").font(.footnote).foregroundStyle(.secondary) }
    }.navigationTitle(title).toolbar {
        ToolbarItem(placement:.cancellationAction) { Button("Cancel") {dismiss()} }
        ToolbarItem(placement:.confirmationAction) { Button("Save") { Task { do { _ = try await store.send(path,method:method,body:record); await store.load(); dismiss() } catch {store.report(error)} } }.bold().disabled(store.saving || required.contains {record[$0].text.trimmingCharacters(in:.whitespaces).isEmpty}) }
    } }.presentationDetents([.large]).presentationDragIndicator(.visible) }
}
struct NativePhoto:View {
    var path:String; var size:CGFloat=72
    var body:some View { AsyncImage(url:URL(string:path.hasPrefix("https://") ? path : CommandPolicy.origin+path)) { image in image.resizable().scaledToFill() } placeholder: { ZStack { Color.secondary.opacity(0.08); Image(systemName:"photo").foregroundStyle(.secondary) } }.frame(width:size,height:size).clipShape(RoundedRectangle(cornerRadius:16)) }
}
struct NativeMediaPicker:View {
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) var dismiss
    var target:String; var menuID:String?=nil
    var select:(String)->Void
    @State private var photo:PhotosPickerItem?
    @State private var uploading=false
    var path:String {"/api/media/library?target=\(target)"}
    var body:some View { NavigationStack { ScrollView { VStack(spacing:20) {
        PhotosPicker(selection:$photo,matching:.images) { Label(uploading ? "Uploading…" : "Upload from Photos",systemImage:"photo.badge.plus").frame(maxWidth:.infinity).padding() }.buttonStyle(.borderedProminent).disabled(uploading)
        LazyVGrid(columns:[GridItem(.adaptive(minimum:120))],spacing:16) { ForEach(store.items(path,"media","items","images")) { item in Button { select(item.first("url","path","image_url")); dismiss() } label: { VStack { NativePhoto(path:item.first("url","path","image_url"),size:110); Text(item.first("name","filename","title")).font(.caption).lineLimit(2) } } } }
    }.padding(24) }.navigationTitle("Picture library").toolbar { Button("Done") {dismiss()} }.task {await store.load(extra:[path])}
    .onChange(of:photo) { _,item in Task { uploading=true; defer {uploading=false}; do {
        guard let bytes=try await item?.loadTransferable(type:Data.self),let image=UIImage(data:bytes) else {return}
        let maxSide:CGFloat=1600; let ratio=min(1,maxSide/max(image.size.width,image.size.height)); let size=CGSize(width:image.size.width*ratio,height:image.size.height*ratio)
        let resized=UIGraphicsImageRenderer(size:size).image {_ in image.draw(in:CGRect(origin:.zero,size:size))}
        guard let data=resized.jpegData(compressionQuality:0.82) else {return}
        var payload:J = .object(["target":.s(target),"filename":.s("hop-ipad-photo.jpg"),"data_url":.s("data:image/jpeg;base64,"+data.base64EncodedString())]); if let menuID {payload["menu_item_id"] = .s(menuID)}
        let response=try await store.send("/api/media/upload",body:payload); let url=response["media"].first("url","path"); guard !url.isEmpty else {throw NativeFailure(status:0,message:"Upload did not return a picture address.")}; select(url);dismiss()
    } catch {store.report(error)} } }
    } }
}
struct DetailPair:View { var title:String; var value:String
    var body:some View { HStack(alignment:.top) {Text(title).foregroundStyle(.secondary); Spacer(); Text(value.isEmpty ? "Not provided" : value).multilineTextAlignment(.trailing) }.font(.subheadline).padding(.vertical,4) }
}
struct NativeRecordSummary:View {
    var record:J; var fields:[String]
    var body:some View { ForEach(fields,id:\.self) { key in DetailPair(title:key.replacingOccurrences(of:"_",with:" ").capitalized,value:record[key].array.isEmpty ? record[key].text : record[key].array.map(\.text).joined(separator:", ")) } }
}
