import Foundation

// Synthetic work only: no server, accounts or customer records.
var rows: [JSONValue] = []
var entries: [JSONValue] = []
for row in 0..<12 {
    rows.append(.object(["id": .string("r\(row)"), "label": .string("Slot \(row)"), "role_group": .string(row < 4 ? "host" : "waitress")]))
    for day in [0, 2, 3, 4, 5, 6] {
        entries.append(.object(["id": .string("time-\(row)-\(day)"), "row_id": .string("r\(row)"), "day_of_week": .number(Double(day)), "employee_id": .string(""), "shift_label": .string("10 AM - 3 PM")]))
        entries.append(.object(["id": .string("entry-\(row)-\(day)"), "row_id": .string("r\(row)"), "day_of_week": .number(Double(day)), "employee_id": .string("employee-\(row)"), "employee_name": .string("Test Employee \(row)")]))
    }
}
let payload = JSONValue.object(["schedule": .object(["status": .string("published"), "rows": .array(rows), "entries": .array(entries)])])
var checksum = 0
let started = ProcessInfo.processInfo.systemUptime
for _ in 0..<20 {
    let shifts = HOPShift.from(payload, week: "2026-09-01")
    checksum += shifts.count + shifts.compactMap(\.minutes).reduce(0, +)
}
print(String(format: "PARSE_20_MS=%.2f CHECKSUM=%d", (ProcessInfo.processInfo.systemUptime - started) * 1000, checksum))
#if HOP_CACHE_BENCH
let projection = HOPScheduleProjection()
projection.update(data: ["team": payload], week: "2026-09-01", employee: HOPRecord(.object(["id": .string("employee-0")])) )
let cacheStarted = ProcessInfo.processInfo.systemUptime
var visibleRows = 0
for _ in 0..<1000 { visibleRows += projection.team.count }
print(String(format: "CACHE_1000_READS_MS=%.3f ROWS=%d REBUILDS=%d", (ProcessInfo.processInfo.systemUptime - cacheStarted) * 1000, visibleRows, projection.rebuildCount))
#endif
