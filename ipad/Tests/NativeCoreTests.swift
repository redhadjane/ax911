import XCTest
@testable import CommandPolicy
final class NativeCoreTests:XCTestCase {
    func testStandardWallBoardFitsOneLandscapePage() {
        for counts in [Array(repeating:1,count:11),Array(repeating:1,count:3),[1,2,1,1,1,1,1,1,1,1,1]] {
            let heights=WallBoardLayout.rowHeights(assignmentCounts:counts)
            XCTAssertEqual(heights.reduce(0,+),WallBoardLayout.gridBottom-WallBoardLayout.gridTop,accuracy:0.01)
            for (index,height) in heights.enumerated() {XCTAssertGreaterThanOrEqual(height,Double(max(1,counts[index])*29+7))}
        }
        XCTAssertEqual(WallBoardLayout.time("16:30:00"),"4:30 PM")
        XCTAssertEqual(WallBoardLayout.time("12:00"),"12:00 PM")
        XCTAssertEqual(WallBoardLayout.time("00:15"),"12:15 AM")
    }
    func testAvailabilityWeekPeriodAndMissingSubmission() {
        let person:J = .object(["id":.s("p")]),row:J = .object(["label":.s("Host AM1"),"role_group":.s("host")])
        let slot:J = .object(["employee_id":.s("p"),"week_start":.s("2026-09-01T00:00:00.000Z"),"day":.s("tuesday"),"shift_key":.s("am"),"status":.s("OFF")])
        XCTAssertTrue(BoardRules.off(person,day:"2026-09-01",row:row,availability:[slot]))
        XCTAssertEqual(BoardRules.availabilityState(person,day:"2026-09-08",row:row,availability:[slot]),"default")
        XCTAssertFalse(BoardRules.off(person,day:"2026-09-01",row:row.set(["label":.s("PM1")]),availability:[slot]))
        XCTAssertEqual(BoardRules.availabilityState(person,day:"2026-09-01",row:row,availability:[slot.set(["status":.s("available")])]),"available")
        XCTAssertEqual(BoardRules.shiftKey(.object(["label":.s("FH1")]),start:"11:00"),"PM")
    }
    func testFloorRoleMatchesBackendRatherThanAllServers() {
        let floor:J = .object(["label":.s("FH1"),"role_group":.s("floor")])
        let person:J = .object(["role":.s("waitress")])
        XCTAssertFalse(BoardRules.roleMatch(person,floor))
        XCTAssertTrue(BoardRules.roleMatch(person.set(["secondary_roles":.array([.s("Floor Help")])]),floor))
        XCTAssertTrue(BoardRules.roleMatch(.object(["role":.s("Manager")]),floor))
    }
    func testRolePayAndUnconfiguredRate() {
        let person:J = .object(["id":.s("p"),"role_pay_rates":.object(["host":.n(1500),"waitress":.n(500)])])
        let schedule:J = .object(["rows":.array([.object(["id":.s("r"),"role_group":.s("host"),"label":.s("AM1")])]),"entries":.array([.object(["id":.s("e"),"row_id":.s("r"),"employee_id":.s("p"),"start_time":.s("10:00"),"end_time":.s("15:00")])])
        let line=LaborLine.make(schedule:schedule,employees:[person])[0]
        XCTAssertEqual(line.hours,5);XCTAssertEqual(line.pay,7500);XCTAssertFalse(line.missingRate)
        XCTAssertTrue(LaborLine.make(schedule:schedule,employees:[])[0].missingRate)
    }
    func testTuesdayWeek() {XCTAssertEqual(HOPDay.week("2026-09-06"),"2026-09-01");XCTAssertEqual(HOPDay.week("2026-09-07"),"2026-09-01");XCTAssertEqual(HOPDay.week("2026-09-08"),"2026-09-08");XCTAssertEqual(HOPDay.days("2026-09-01").last,"2026-09-06")}
    func testDateBoundary() {XCTAssertEqual(HOPDay.add("2026-12-31",1),"2027-01-01");XCTAssertEqual(HOPDay.weekday("2026-09-17"),4);XCTAssertNil(HOPDay.parse("09/17/2026"));XCTAssertEqual(HOPDay.label("2026-09-17","EEEE"),"Thursday")}
    func testDecimalMoney() {XCTAssertEqual(HOPMoney.cents("19.99"),1999);XCTAssertEqual(HOPMoney.cents("1.005"),101);XCTAssertEqual(HOPMoney.cents("not money"),0)}
    func testInvoiceParity() {let d:J = .object(["items":.array([.object(["quantity":.n(3),"unit_price_cents":.n(38500)]),.object(["quantity":.n(13),"unit_price_cents":.n(4950)]),.object(["quantity":.n(2),"unit_price_cents":.n(4950)])]),"tax_rate_basis_points":.n(1000),"delivery_fee_cents":.n(2000),"card_fee_basis_points":.n(350)]);let t=HOPMoney.totals(d);XCTAssertEqual(t["subtotal_cents"].int,189750);XCTAssertEqual(t["tax_cents"].int,18975);XCTAssertEqual(t["total_cents"].int,210725);XCTAssertEqual(t["card_total_cents"].int,218100)}
    func testDiscountBeforeTaxAndSingleDelivery() {let d:J = .object(["items":.array([.object(["quantity":.n(1),"unit_price_cents":.n(10000)])]),"discount_cents":.n(500),"discount_basis_points":.n(1000),"tax_rate_basis_points":.n(1000),"delivery_fee_cents":.n(1000)]);let t=HOPMoney.totals(d);XCTAssertEqual(t["applied_discount_cents"].int,1500);XCTAssertEqual(t["tax_cents"].int,850);XCTAssertEqual(t["total_cents"].int,10350);XCTAssertEqual(t["discount_cents"].int,500)}
    func testRoleAndAvailability() {let person:J = .object(["id":.s("p"),"role":.s("host"),"secondary_roles":.array([.s("waitress")])]);let row:J = .object(["role_group":.s("waitress"),"label":.s("AM1")]);XCTAssertTrue(BoardRules.roleMatch(person,row));let slots:[J] = [.object(["employee_id":.s("p"),"day":.s("Tue"),"shift_key":.s("AM"),"status":.s("off")])];XCTAssertTrue(BoardRules.off(person,day:"2026-09-01",row:row,availability:slots))}
    func testNoFalseOverlapAtBoundary() {let first:J = .object(["id":.s("1"),"employee_id":.s("p"),"day_of_week":.n(2),"start_time":.s("10:00:00"),"end_time":.s("15:00:00")]);let next=first.set(["id":.s("2"),"start_time":.s("15:00"),"end_time":.s("20:00")]);XCTAssertFalse(BoardRules.overlaps(next,[first]));XCTAssertTrue(BoardRules.overlaps(next.set(["start_time":.s("14:59")]),[first]));XCTAssertFalse(BoardRules.overlaps(first,[first]))}
    func testShiftTaskMapping() {let row:J = .object(["role_group":.s("floor"),"label":.s("FH2")]);let task:J = .object(["role_group":.s("support"),"shift":.s("PM"),"shift_number":.n(2),"day_of_week":.n(5)]);XCTAssertTrue(BoardRules.taskMatches(task,row:row,day:"2026-09-04"));XCTAssertFalse(BoardRules.taskMatches(task,row:row,day:"2026-09-05"))}
    func testClosedMarker() {XCTAssertTrue(BoardRules.closed([.object(["notes":.s("HOP_SLOT_INACTIVE")])]));XCTAssertFalse(BoardRules.closed([.object(["notes":.s("HOP_SLOT_ACTIVE")])]))}
    func testSavedDiscountDoesNotDoubleApply() {let saved:J = .object(["subtotal_cents":.n(10000),"discount_cents":.n(1500),"discount_basis_points":.n(1000),"items":.array([.object(["quantity":.n(1),"unit_price_cents":.n(10000)])])]);let edit=HOPMoney.editableInvoice(saved);XCTAssertEqual(edit["discount_cents"].int,500);XCTAssertEqual(HOPMoney.totals(edit)["applied_discount_cents"].int,1500)}
    func testDefaultInactiveCellsAndExplicitReopen() {let row:J = .object(["row_key":.s("main_am3")]);XCTAssertTrue(BoardRules.cellClosed([],row:row,day:"2026-09-01"));XCTAssertFalse(BoardRules.cellClosed([],row:row,day:"2026-09-06"));XCTAssertFalse(BoardRules.cellClosed([.object(["notes":.s("HOP_SLOT_ACTIVE")])],row:row,day:"2026-09-01"));XCTAssertFalse(BoardRules.closed([.object(["notes":.s("HOP_SLOT_INACTIVE HOP_SLOT_ACTIVE")])]))}
}
