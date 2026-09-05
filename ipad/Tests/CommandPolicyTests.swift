import XCTest
@testable import CommandPolicy
final class CommandPolicyTests: XCTestCase {
    func testLiveAPIAndAllMutationMethods() {
        for method in CommandPolicy.methods {
            XCTAssertNotNil(CommandPolicy.apiURL(CommandPolicy.origin + "/api/invoices?archived=true", method: method))
        }
    }
    func testCredentialExfiltrationTargetsAreBlocked() {
        for value in ["http://www.houseofpizzagaffney.com/api/employees", "https://evil.test/api/employees", "https://www.houseofpizzagaffney.com.evil.test/api/", "https://user@www.houseofpizzagaffney.com/api/", "https://www.houseofpizzagaffney.com:444/api/", "file:///api/employees", CommandPolicy.origin + "/employee/", CommandPolicy.origin + "/api/%2e%2e/employee", CommandPolicy.origin + "/api/../employee", CommandPolicy.origin + "/api/test#fragment"] {
            XCTAssertNil(CommandPolicy.apiURL(value, method: "GET"), value)
        }
        XCTAssertNil(CommandPolicy.apiURL(CommandPolicy.origin + "/api/settings", method: "CONNECT"))
    }
    func testOnlyBundledMainDocumentIsTrusted() {
        let root = URL(fileURLWithPath: "/App/Web", isDirectory: true)
        XCTAssertTrue(CommandPolicy.isBundledPage(root.appendingPathComponent("index.html"), root: root))
        XCTAssertFalse(CommandPolicy.isBundledPage(URL(string: CommandPolicy.origin), root: root))
        XCTAssertFalse(CommandPolicy.isBundledPage(root.appendingPathComponent("other.html"), root: root))
    }
    func testSafeExportsAndExternalLinks() {
        XCTAssertEqual(CommandPolicy.exportName("HOP-Schedule.png"), "HOP-Schedule.png")
        XCTAssertNil(CommandPolicy.exportName("../../private.pdf"))
        XCTAssertNil(CommandPolicy.exportName("script.html"))
        XCTAssertNotNil(CommandPolicy.externalURL("tel:8640000000"))
        XCTAssertNil(CommandPolicy.externalURL("javascript:alert(1)"))
        XCTAssertNil(CommandPolicy.externalURL("file:///private/foo"))
    }
}
