import XCTest
#if canImport(HOPCore)
@testable import HOPCore
#else
@testable import HOPEmployee
#endif

final class HOPCoreTests: XCTestCase {
    private func json(_ value: String) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self, from: Data(value.utf8)) }
    private func payload(entries: [JSONValue], status: String = "published") -> JSONValue {
        .object(["schedule": .object(["status": .string(status), "rows": .array([
            .object(["id": .string("row-main"), "label": .string("AM1"), "role_group": .string("waitress"), "row_key": .string("main_am1")]),
            .object(["id": .string("row-host"), "label": .string("Host PM1"), "role_group": .string("host")]),
            .object(["id": .string("row-floor"), "label": .string("FH1"), "role_group": .string("floor")])]), "entries": .array(entries)])])
    }
    private func entry(_ id: String = "entry", employee: String = "employee-a", row: String = "row-main", day: Int = 4, start: String = "10:00:00", end: String = "15:00:00", label: String = "", notes: String = "") -> JSONValue {
        .object(["id": .string(id), "employee_id": .string(employee), "row_id": .string(row), "day_of_week": .number(Double(day)), "start_time": .string(start), "end_time": .string(end), "shift_label": .string(label), "notes": .string(notes)])
    }
    func testJSONPreservesNumericStringsNullAndBooleans() throws {
        let value = try json("{\"count\":\"12\",\"amount\":12.5,\"locked\":true,\"name\":null}")
        XCTAssertEqual(value["count"].number, 12); XCTAssertEqual(value["amount"].text, "12.5")
        XCTAssertTrue(value["locked"].flag); XCTAssertEqual(value["name"], .null)
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value)), value)
    }
    func testPostgresCalendarDateDoesNotShiftToPreviousDay() {
        XCTAssertEqual(HOPCalendar.calendar.component(.weekday, from: HOPCalendar.date("2026-09-17T00:00:00.000Z")!), 5)
        XCTAssertEqual(HOPCalendar.tuesday("2026-09-17T00:00:00.000Z"), "2026-09-15")
    }
    func testTodayUsesRestaurantTimezoneAcrossUTCMidnight() {
        let formatter = ISO8601DateFormatter()
        XCTAssertEqual(HOPCalendar.today(formatter.date(from: "2026-09-05T02:00:00Z")!), "2026-09-04")
        XCTAssertEqual(HOPCalendar.today(formatter.date(from: "2026-01-03T02:00:00Z")!), "2026-01-02")
    }
    func testTuesdaySundayAndMondayBoundaries() {
        XCTAssertEqual(HOPCalendar.tuesday("2026-09-06"), "2026-09-01")
        XCTAssertEqual(HOPCalendar.tuesday("2026-09-07"), "2026-09-01")
        XCTAssertEqual(HOPCalendar.tuesday("2026-09-08"), "2026-09-08")
        XCTAssertEqual(HOPCalendar.shiftDate(week: "2026-09-01", day: 0), "2026-09-06")
    }
    func testDSTCalendarArithmeticAndInvalidDates() {
        XCTAssertEqual(HOPCalendar.add("2026-03-07", days: 2), "2026-03-09")
        XCTAssertEqual(HOPCalendar.add("2026-10-31", days: 2), "2026-11-02")
        XCTAssertNil(HOPCalendar.date("2026-02-30")); XCTAssertNil(HOPCalendar.date("09/17/2026"))
    }
    func testClockAndLegacyLabelParsing() {
        XCTAssertEqual(HOPCalendar.clock("00:00:00"), "12:00 AM")
        XCTAssertEqual(HOPCalendar.clock("12:30:00"), "12:30 PM")
        XCTAssertEqual(HOPCalendar.labelTimes("10:00 AM – 3:00 PM"), ["10:00", "15:00"])
        XCTAssertEqual(HOPCalendar.labelTimes("4-8 PM"), ["16:00", "20:00"])
        XCTAssertEqual(HOPCalendar.labelTimes("22:00 - 02:00"), ["22:00", "02:00"])
        XCTAssertTrue(HOPCalendar.labelTimes("Not a time").isEmpty)
    }
    func testPublishedOnlyAndEmployeeIsolation() {
        let values = [entry(), entry("other", employee: "employee-b", row: "row-host")]
        XCTAssertTrue(HOPShift.from(payload(entries: values, status: "draft"), week: "2026-09-15").isEmpty)
        let mine = HOPShift.from(payload(entries: values), week: "2026-09-15", employeeID: "employee-a")
        XCTAssertEqual(mine.count, 1); XCTAssertEqual(mine.first?.date, "2026-09-17")
    }
    func testDuplicateEntryIsNotDoubleButSeparateShiftIs() {
        let shifts = HOPShift.from(payload(entries: [entry(), entry("duplicate"), entry("evening", row: "row-host", start: "16:00", end: "20:00")]), week: "2026-09-15")
        XCTAssertEqual(shifts.count, 2)
        XCTAssertEqual(shifts.map(\.role), ["Serving", "Hosting"])
        XCTAssertEqual(shifts.compactMap(\.minutes).reduce(0, +), 540)
    }
    func testRoleAndDirectoryNameResolution() {
        let shifts = HOPShift.from(payload(entries: [entry(row: "row-floor")]), week: "2026-09-15")
        XCTAssertEqual(shifts.first?.role, "Floor help")
        XCTAssertEqual(shifts.first?.named("Real Employee").employeeName, "Real Employee")
    }
    func testClosedMarkerAndExplicitReopenedMarker() {
        XCTAssertTrue(HOPShift.from(payload(entries: [entry(notes: "HOP_SLOT_INACTIVE")]), week: "2026-09-15").isEmpty)
        XCTAssertEqual(HOPShift.from(payload(entries: [entry(notes: "HOP_SLOT_INACTIVE HOP_SLOT_ACTIVE")]), week: "2026-09-15").count, 1)
    }
    func testRowDayTimeRecordSuppliesLegacyAssignedTimes() {
        let shifts = HOPShift.from(payload(entries: [entry("time", employee: "", start: "", end: "", label: "10 AM - 3 PM"), entry(start: "", end: "")]), week: "2026-09-15")
        XCTAssertEqual(shifts.first?.start, "10:00"); XCTAssertEqual(shifts.first?.end, "15:00"); XCTAssertEqual(shifts.first?.minutes, 300)
    }
    func testFallbackServicePayloadIsNotPublishedData() {
        var value = payload(entries: [entry()]).fields; value["fallback"] = .bool(true); value["database_available"] = .bool(false)
        XCTAssertTrue(HOPShift.from(.object(value), week: "2026-09-15").isEmpty)
    }
    func testOvernightEndAndFutureInstants() {
        let shifts = HOPShift.from(payload(entries: [entry(start: "22:00", end: "02:00")]), week: "2026-09-15")
        XCTAssertEqual(shifts.first?.minutes, 240)
        XCTAssertEqual(HOPCalendar.key(shifts.first!.endInstant!), "2026-09-18")
    }
    func testNotificationLinksStayInsideKnownNativeScreens() {
        XCTAssertEqual(HOPLink.notification(HOPRecord(.object(["category": .string("request")]))), .requests)
        XCTAssertEqual(HOPLink.notification(HOPRecord(.object(["payload": .object(["url": .string("/employee/?screen=availability")])]))), .availability)
        XCTAssertEqual(HOPLink.notification(HOPRecord(.object(["payload": .object(["url": .string("https://untrusted.invalid/login")])]))), .notifications)
    }
    func testCalendarExportUsesRealDatesUTCTimesAndEscaping() {
        let shift = HOPShift.from(payload(entries: [entry()]), week: "2026-09-15")[0]
        let result = HOPExport.calendar([shift], now: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(result.contains("DTSTART:20260917T140000Z")); XCTAssertTrue(result.contains("DTEND:20260917T190000Z"))
        XCTAssertTrue(result.contains("UID:entry@houseofpizzagaffney.com")); XCTAssertTrue(result.hasSuffix("END:VCALENDAR\r\n"))
    }
    func testProjectionReusesScheduleWhenUnrelatedMessagesChange() {
        let projection = HOPScheduleProjection()
        let person = HOPRecord(.object(["id": .string("employee-a"), "name": .string("Pilot")]))
        var data = ["mine": payload(entries: [entry()]), "team": payload(entries: [entry(), entry("b", employee: "employee-b", row: "row-host")])]
        projection.update(data: data, week: "2026-09-15", employee: person)
        let builds = projection.rebuildCount
        for i in 0..<1000 {
            XCTAssertEqual(projection.mine.count, 1); XCTAssertEqual(projection.team.count, 2)
            data["notifications"] = .number(Double(i))
            projection.update(data: data, week: "2026-09-15", employee: person)
        }
        XCTAssertEqual(projection.rebuildCount, builds, "Messages and scrolling must not reparse the schedule")
        XCTAssertEqual(projection.mine[0].employeeName, "Pilot")
    }
    func testProjectionInvalidatesNamesWeekAndAccountAndClearsOnLogout() {
        let projection = HOPScheduleProjection()
        let a = HOPRecord(.object(["id": .string("employee-a"), "name": .string("Pilot A")]))
        let b = HOPRecord(.object(["id": .string("employee-b"), "name": .string("Pilot B")]))
        var data = ["mine": payload(entries: [entry(), entry("b", employee: "employee-b", row: "row-host")])]
        projection.update(data: data, week: "2026-09-15", employee: a)
        data["directory"] = .object(["employees": .array([.object(["id": .string("employee-a"), "name": .string("Updated A")])])])
        projection.update(data: data, week: "2026-09-15", employee: a)
        XCTAssertEqual(projection.mine.first?.employeeName, "Updated A")
        projection.update(data: data, week: "2026-09-22", employee: b)
        XCTAssertEqual(projection.mine.map(\.employeeID), ["employee-b"])
        XCTAssertEqual(projection.mine.first?.date, "2026-09-24")
        projection.update(data: [:], week: "2026-09-22", employee: nil)
        XCTAssertTrue(projection.mine.isEmpty && projection.team.isEmpty && projection.next.isEmpty)
    }
    func testProjectionNeverTurnsDraftIntoPublishedData() {
        let projection = HOPScheduleProjection()
        let person = HOPRecord(.object(["id": .string("employee-a")]))
        projection.update(data: ["team": payload(entries: [entry()], status: "draft")], week: "2026-09-15", employee: person)
        XCTAssertTrue(projection.team.isEmpty)
    }
    func testIndexedCellsDoNotMixTimeAndClosureAcrossRowsOrDays() {
        let values = [entry("time", employee: "", label: "10 AM - 3 PM"), entry(),
                      entry("closed", row: "row-host", notes: "HOP_SLOT_INACTIVE"),
                      entry("other-day", row: "row-host", day: 5, start: "16:00", end: "20:00")]
        let shifts = HOPShift.from(payload(entries: values), week: "2026-09-15")
        XCTAssertEqual(shifts.map(\.id), ["entry", "other-day"])
        XCTAssertEqual(shifts.last?.time, "4:00 PM – 8:00 PM")
    }
    func testRefreshPlansKeepSmallActionsAndStartupScoped() {
        XCTAssertEqual(HOPRefreshPlan.sections(for: .home), ["mine", "next", "notifications", "profile"])
        XCTAssertEqual(HOPRefreshPlan.afterAction("/api/notifications/item/read"), ["notifications"])
        XCTAssertEqual(HOPRefreshPlan.afterAction("/api/tasks/complete"), ["tasks"])
        XCTAssertTrue(HOPRefreshPlan.sections(for: .schedule).contains("directory"))
        XCTAssertTrue(HOPRefreshPlan.sections(for: .requests).contains("history"))
        XCTAssertFalse(HOPRefreshPlan.weekScoped.contains("notifications"))
        XCTAssertFalse(HOPRefreshPlan.weekScoped.contains("directory"))
        XCTAssertTrue(HOPRefreshPlan.weekScoped.contains("mine"))
    }
    func testFastCalendarParserRetainsStrictValidation() {
        XCTAssertNil(HOPCalendar.date("2026-13-01")); XCTAssertNil(HOPCalendar.date("2026-00-01"))
        XCTAssertNil(HOPCalendar.date("2026-09-00")); XCTAssertNil(HOPCalendar.date("2026-9-01"))
        XCTAssertNil(HOPCalendar.date("2025-02-29")); XCTAssertNil(HOPCalendar.date("0000-01-01"))
        XCTAssertEqual(HOPCalendar.key(HOPCalendar.date("2028-02-29")!), "2028-02-29")
    }
}
