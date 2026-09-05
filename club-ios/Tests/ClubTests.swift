import XCTest
@testable import ClubCore

final class ClubTests:XCTestCase {
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
    func testRejectsUntrustedQRMarkupAndOutOfBounds() {
        for svg in ["<!DOCTYPE svg><svg/>","<svg viewBox=\"0 0 25 25\"><script>alert(1)</script></svg>","<svg viewBox=\"0 0 25 25\"><path stroke=\"#000\" d=\"M0 0h999\"/></svg>","<svg viewBox=\"0 0 25 25\"><path stroke=\"#000\" d=\"M2 2.5h7Q4 4\"/></svg>"] {XCTAssertNil(ClubQR.parse(Data(svg.utf8)))}
    }
}
