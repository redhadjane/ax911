import XCTest
@testable import ClubCore

final class ClubTests:XCTestCase {
    func testBuilderArtworkUsesCurrentLabelNotLegacyOptionID() {
        let option:J = .object(["id":.s("topping-chicken"),"name":.s("Green Peppers")])
        let group:J = .object(["id":.s("toppings"),"name":.s("Toppings"),"allow_half":.bool(true),"options":.array([option])])
        let item:J = .object(["name":.s("Steak Pizza"),"customization":.object(["modifier_groups":.array([group])])])
        let choice:J = .object(["option_id":.s(option.id),"portion":.s("left"),"style":.s("extra"),"quantity":.n(1)])
        let layer=ClubBuilder.layers(item,selections:[group.id:[choice]]).first
        XCTAssertEqual(layer?.kind,.pepper);XCTAssertEqual(layer?.portion,"left");XCTAssertEqual(layer?.style,"extra")
        XCTAssertEqual(ClubIngredient.identify("Pinnapple"),.pineapple)
        XCTAssertEqual(ClubIngredient.identify("Jalopinios"),.jalapeno)
    }
    func testBuilderStepsHaveSizeBaseToppingsAndReview() {
        let crust:J = .object(["id":.s("crust"),"name":.s("Crust"),"sort_order":.n(10)])
        let toppings:J = .object(["id":.s("toppings"),"name":.s("Toppings"),"allow_half":.bool(true)])
        let item:J = .object(["name":.s("Pizza"),"size_prices":.object(["Large":.n(20)]),"customization":.object(["modifier_groups":.array([toppings,crust])])])
        XCTAssertEqual(ClubBuilder.steps(item).map(\.id),["size","base","toppings","finish"])
        XCTAssertEqual(ClubBuilder.steps(.object(["name":.s("Spaghetti")])).map(\.id),["finish"])
        XCTAssertFalse(ClubBuilder.isPizza(.object(["name":.s("Dessert Pizza")])))
    }
    func testHalfToppingPositionsAreDeterministicAndStayOnCorrectSide() {
        for portion in ["left","right","whole"] {
            let a=ClubBuilder.positions(seed:"same",portion:portion,count:20),b=ClubBuilder.positions(seed:"same",portion:portion,count:20)
            XCTAssertEqual(a.count,20)
            for index in a.indices {XCTAssertEqual(a[index].0,b[index].0);XCTAssertEqual(a[index].1,b[index].1);XCTAssertLessThan(hypot(a[index].0,a[index].1),0.9);if portion == "left" {XCTAssertLessThan(a[index].0,0)};if portion == "right" {XCTAssertGreaterThan(a[index].0,0)}}
        }
        XCTAssertEqual(ClubBuilder.positions(seed:"bounded",portion:"whole",count:9999).count,80)
    }
    func testBuilderHonorsLimitsAndActualPortionAndStyleCapabilities() {
        let option:J = .object(["id":.s("a"),"name":.s("Pepperoni"),"allow_whole":.bool(false),"allow_left":.bool(true),"allow_right":.bool(false),"available_as_extra":.bool(false),"default_selected":.bool(true)])
        let other:J = .object(["id":.s("b"),"name":.s("Ham")])
        let group:J = .object(["id":.s("g"),"allow_half":.bool(true),"supports_styles":.bool(true),"max_selections":.n(1),"options":.array([option,other])])
        XCTAssertEqual(ClubBuilder.portions(group,option),["left"])
        XCTAssertEqual(ClubBuilder.styles(group,option),["regular"])
        let selected=ClubBuilder.toggle(group,option:option,current:[])
        XCTAssertEqual(selected.first?["portion"].text,"left")
        XCTAssertEqual(ClubBuilder.toggle(group,option:other,current:selected),selected)
        XCTAssertTrue(ClubBuilder.toggle(group,option:option,current:selected).isEmpty)
        let item:J = .object(["customization":.object(["modifier_groups":.array([group])])])
        XCTAssertEqual(ClubMenuRules.defaults(item)["g"]?.first?["portion"].text,"left")
    }
    func testSideToppingsNotPaintedOnPizzaAndEditingPreservesWireIDs() {
        let option:J = .object(["id":.s("a"),"name":.s("Mushroom"),"max_quantity":.n(2)])
        let group:J = .object(["id":.s("g"),"name":.s("Toppings"),"supports_styles":.bool(true),"max_selections":.n(3),"options":.array([option])])
        let item:J = .object(["id":.s("pizza"),"name":.s("Pizza"),"customization":.object(["modifier_groups":.array([group])])])
        let side:J = .object(["option_id":.s("a"),"portion":.s("whole"),"style":.s("side"),"quantity":.n(1)])
        XCTAssertTrue(ClubBuilder.layers(item,selections:["g":[side]]).isEmpty)
        let line=ClubMenuRules.line(item,size:"Large",quantity:2,selections:["g":[side]],notes:"Please call")
        let restored=ClubBuilder.restore(item,line:line)
        XCTAssertEqual(restored["g"]?.first?["option_id"].text,"a")
        XCTAssertEqual(restored["g"]?.first?["style"].text,"regular") // unsupported on-side removed from new catalog
        let wire=ClubMenuRules.requestItems([line])[0]
        XCTAssertTrue(wire["display_options"].isNull);XCTAssertTrue(wire["image_url"].isNull);XCTAssertTrue(wire["price"].isNull)
    }
    func testStableSnapshotsDoNotRequoteBecauseDictionaryOrderChanged() {
        XCTAssertEqual(J.object(["b":.n(2),"a":.n(1)]).pretty,J.object(["a":.n(1),"b":.n(2)]).pretty)
    }
    func testCustomerOnlyRoutes() {
        XCTAssertNotNil(ClubPolicy.url("/api/hopclub/v2/me"))
        XCTAssertNotNil(ClubPolicy.url("/api/hopclub/v2/orders",method:"POST"))
        XCTAssertNotNil(ClubPolicy.url("/api/hopclub/v2/redemptions/11111111-2222-3333-4444-555555555555/qr"))
        for path in ["/api/hopclub/admin/customers","/api/hopclub/v2/staff/login","/api/hopclub/signup","/api/hopclub/me?customer_id=other","/api/command-auth/login","/api/employees","https://evil.example/api/hopclub/v2/me","/api/hopclub/v2/../staff/member","/api/hopclub/v2/%6de","/api/hopclub/v2/me#fragment"] {
            XCTAssertNil(ClubPolicy.url(path));XCTAssertNil(ClubPolicy.url(path,method:"POST"))
        }
        XCTAssertNil(ClubPolicy.url("/api/hopclub/v2/me",method:"DELETE"))
    }
    func testMediaBoundary() {
        XCTAssertNotNil(ClubPolicy.media("/public/assets/example.webp"))
        XCTAssertNil(ClubPolicy.media("http://www.houseofpizzagaffney.com/photo.png"))
        XCTAssertNil(ClubPolicy.media("https://evil.example/photo.png"))
        XCTAssertNil(ClubPolicy.media("//evil.example/photo.png"))
        XCTAssertNil(ClubPolicy.media("/api/hopclub/v2/me"))
    }
    func testRequiredModifierAndDefaults() {
        let group:J = .object(["id":.s("g"),"name":.s("Salad"),"selection_type":.s("single"),"required":.bool(true),"max_selections":.n(1),"options":.array([.object(["id":.s("a"),"default_selected":.bool(true)])])])
        let item:J = .object(["id":.s("i"),"name":.s("Pasta"),"customization":.object(["modifier_groups":.array([group])])])
        XCTAssertNotNil(ClubMenuRules.validation(item,size:"Regular",selections:[:]))
        let defaults=ClubMenuRules.defaults(item)
        XCTAssertNil(ClubMenuRules.validation(item,size:"Regular",selections:defaults))
        XCTAssertEqual(defaults["g"]?[0]["portion"].text,"whole")
        XCTAssertNotNil(ClubMenuRules.validation(item,size:"Regular",selections:["g":[.null,.null]]))
    }
    func testCatalogIdentityAndNoClientPrice() {
        let item:J = .object(["id":.s("i"),"name":.s("Pizza"),"price":.n(999),"size_prices":.object(["Small":.n(10),"Large":.n(20)])])
        XCTAssertEqual(ClubMenuRules.sizes(item),["Small","Large"])
        XCTAssertNotNil(ClubMenuRules.validation(item,size:"Invalid",selections:[:]))
        let line=ClubMenuRules.line(item,size:"Large",quantity:2,selections:[:],notes:"No onions")
        let request=ClubMenuRules.requestItems([line])[0]
        XCTAssertEqual(request["menu_item_id"].text,"i");XCTAssertEqual(request["quantity"].int,2)
        XCTAssertTrue(request["price"].isNull);XCTAssertTrue(request["customer_id"].isNull);XCTAssertTrue(request["name"].isNull)
    }
    func testServerQRCodeModuleStrokes() {
        let data=Data("<svg viewBox=\"0 0 25 25\"><path fill=\"#fff\" d=\"M0 0h25v25H0z\"/><path stroke=\"#000\" d=\"M2 2.5h7m1 0h1M2 3.5h1\"/></svg>".utf8)
        let qr=ClubQR.parse(data)
        XCTAssertEqual(qr?.dimension,25)
        XCTAssertEqual(qr?.runs,[ClubQR.Run(x:2,y:2,width:7),ClubQR.Run(x:10,y:2,width:1),ClubQR.Run(x:2,y:3,width:1)])
    }
    func testLocalBagDescriptionsDoNotLeakIntoOrderContract() {
        let option:J = .object(["id":.s("pep"),"name":.s("Pepperoni")])
        let group:J = .object(["id":.s("topping"),"options":.array([option])])
        let item:J = .object(["id":.s("pizza"),"name":.s("Pizza"),"image_url":.s("/pizza.jpg"),"customization":.object(["modifier_groups":.array([group])])])
        let selected:J = .object(["option_id":.s("pep"),"portion":.s("left"),"style":.s("extra"),"quantity":.n(2)])
        let line=ClubMenuRules.line(item,size:"Large",quantity:1,selections:["topping":[selected]],notes:"")
        XCTAssertEqual(line["display_options"].array.map(\.text),["Pepperoni · left half · extra · ×2"])
        let request=ClubMenuRules.requestItems([line])[0]
        XCTAssertTrue(request["display_options"].isNull)
        XCTAssertTrue(request["image_url"].isNull)
        XCTAssertEqual(request["modifier_selections"].array[0]["options"].array[0]["option_id"].text,"pep")
    }
    func testRejectsUntrustedQRMarkupAndOutOfBounds() {
        for svg in ["<!DOCTYPE svg><svg/>","<svg viewBox=\"0 0 25 25\"><script>alert(1)</script></svg>","<svg viewBox=\"0 0 25 25\"><path stroke=\"#000\" d=\"M0 0h999\"/></svg>","<svg viewBox=\"0 0 25 25\"><path stroke=\"#000\" d=\"M2 2.5h7Q4 4\"/></svg>"] {XCTAssertNil(ClubQR.parse(Data(svg.utf8)))}
    }
}
