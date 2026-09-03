import Foundation
import CoreBluetooth

struct VehicleSnapshot {
    var vin: String = ""
    var dtcs: [String] = []
    var rpm: Double?
    var speedMph: Double?
    var coolantF: Double?
    var loadPct: Double?
    var throttlePct: Double?
    var intakeAirF: Double?
    var shortFuelTrimPct: Double?
    var longFuelTrimPct: Double?
    var fuelPct: Double?
    var voltage: Double?
}

final class OBDLinkCXManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    enum State: Equatable {
        case idle, scanning, connecting, connected, reading, finished, failed(String)
    }

    @Published var state: State = .idle
    @Published var progress: Int = 0
    @Published var message: String = "Ready to connect"
    @Published var snapshot = VehicleSnapshot()

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?

    private let uartService = CBUUID(string: "FFF0")
    private let notifyUUID = CBUUID(string: "FFF1")
    private let writeUUID = CBUUID(string: "FFF2")

    private var receiveBuffer = ""
    private var queue: [String] = []
    private var currentCommand: String?
    private var responses: [String: String] = [:]
    private var timeout: DispatchWorkItem?

    func connect() {
        snapshot = VehicleSnapshot()
        responses.removeAll()
        progress = 3
        message = "Starting Bluetooth…"
        state = .scanning
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        } else if central.state == .poweredOn {
            startScan()
        }
    }

    func disconnect() {
        timeout?.cancel()
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        cleanup()
        state = .idle
        progress = 0
        message = "Disconnected"
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScan()
        case .poweredOff:
            fail("Bluetooth is turned off.")
        case .unauthorized:
            fail("Bluetooth permission was not granted.")
        case .unsupported:
            fail("Bluetooth Low Energy is not supported on this device.")
        default:
            break
        }
    }

    private func startScan() {
        state = .scanning
        progress = 10
        message = "Looking for OBDLink CX…"
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, self.peripheral == nil, self.state == .scanning else { return }
            self.central.stopScan()
            self.fail("No OBDLink CX was found. Plug it into the OBD-II port, switch the ignition on, then try again.")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = (peripheral.name ?? advertisedName ?? "").lowercased()
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        guard name.contains("obdlink") || services.contains(uartService) else { return }
        self.peripheral = peripheral
        central.stopScan()
        state = .connecting
        progress = 20
        message = "OBDLink CX found • connecting…"
        peripheral.delegate = self
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        progress = 28
        message = "Discovering secure BLE service…"
        peripheral.discoverServices([uartService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        fail(error?.localizedDescription ?? "Could not connect to OBDLink CX.")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if case .idle = state { return }
        cleanup(keepCentral: true)
        state = .idle
        progress = 0
        message = "OBDLink disconnected"
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { fail(error.localizedDescription); return }
        guard let service = peripheral.services?.first(where: { $0.uuid == uartService }) else {
            fail("The OBDLink CX UART service was not found.")
            return
        }
        peripheral.discoverCharacteristics([notifyUUID, writeUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error { fail(error.localizedDescription); return }
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == notifyUUID { notifyCharacteristic = characteristic }
            if characteristic.uuid == writeUUID { writeCharacteristic = characteristic }
        }
        guard let notifyCharacteristic, writeCharacteristic != nil else {
            fail("The OBDLink serial channel was not found.")
            return
        }
        progress = 36
        message = "Pairing encrypted Bluetooth session…"
        peripheral.setNotifyValue(true, for: notifyCharacteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error { fail(error.localizedDescription); return }
        guard characteristic.uuid == notifyUUID, characteristic.isNotifying else { return }
        state = .connected
        progress = 42
        message = "Connected • preparing vehicle scan…"
        beginReadSession()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { fail(error.localizedDescription); return }
        guard characteristic.uuid == notifyUUID,
              let data = characteristic.value,
              let text = String(data: data, encoding: .utf8) else { return }
        receiveBuffer += text
        if receiveBuffer.contains(">") { finishCommand() }
    }

    private func beginReadSession() {
        state = .reading
        responses.removeAll()
        queue = [
            "ATZ", "ATE0", "ATL0", "ATS0", "ATH0", "ATSP0",
            "0902", "03", "010C", "010D", "0105", "0104", "0111", "010F", "0106", "0107", "012F", "ATRV"
        ]
        sendNext()
    }

    private func sendNext() {
        timeout?.cancel()
        guard currentCommand == nil else { return }
        guard !queue.isEmpty else {
            publishSnapshot()
            return
        }
        let command = queue.removeFirst()
        currentCommand = command
        receiveBuffer = ""
        progress = max(progress, min(94, 45 + Int(Double(18 - queue.count) / 18.0 * 49.0)))
        message = label(for: command)

        guard let peripheral, let writeCharacteristic,
              let data = (command + "\r").data(using: .utf8) else {
            fail("The OBDLink write channel is unavailable.")
            return
        }

        let maxLength = max(20, peripheral.maximumWriteValueLength(for: .withoutResponse))
        var offset = 0
        while offset < data.count {
            let end = min(data.count, offset + maxLength)
            peripheral.writeValue(data.subdata(in: offset..<end), for: writeCharacteristic, type: .withoutResponse)
            offset = end
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self, let command = self.currentCommand else { return }
            self.responses[command] = self.receiveBuffer
            self.currentCommand = nil
            self.receiveBuffer = ""
            self.sendNext()
        }
        timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (command == "ATZ" ? 4.0 : 2.2), execute: work)
    }

    private func finishCommand() {
        timeout?.cancel()
        guard let command = currentCommand else { return }
        responses[command] = receiveBuffer
        currentCommand = nil
        receiveBuffer = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.sendNext() }
    }

    private func publishSnapshot() {
        var s = VehicleSnapshot()
        s.vin = parseVIN(responses["0902"] ?? "") ?? ""
        s.dtcs = parseDTCs(responses["03"] ?? "")

        if let v = parsePID(responses["010C"] ?? "", pid: 0x0C), v.count >= 2 {
            s.rpm = Double(Int(v[0]) * 256 + Int(v[1])) / 4.0
        }
        if let a = parsePID(responses["010D"] ?? "", pid: 0x0D)?.first {
            s.speedMph = Double(a) * 0.621371
        }
        if let a = parsePID(responses["0105"] ?? "", pid: 0x05)?.first {
            s.coolantF = (Double(Int(a) - 40) * 9.0 / 5.0) + 32.0
        }
        if let a = parsePID(responses["0104"] ?? "", pid: 0x04)?.first {
            s.loadPct = Double(a) * 100.0 / 255.0
        }
        if let a = parsePID(responses["0111"] ?? "", pid: 0x11)?.first {
            s.throttlePct = Double(a) * 100.0 / 255.0
        }
        if let a = parsePID(responses["010F"] ?? "", pid: 0x0F)?.first {
            s.intakeAirF = (Double(Int(a) - 40) * 9.0 / 5.0) + 32.0
        }
        if let a = parsePID(responses["0106"] ?? "", pid: 0x06)?.first {
            s.shortFuelTrimPct = (Double(Int(a) - 128) * 100.0) / 128.0
        }
        if let a = parsePID(responses["0107"] ?? "", pid: 0x07)?.first {
            s.longFuelTrimPct = (Double(Int(a) - 128) * 100.0) / 128.0
        }
        if let a = parsePID(responses["012F"] ?? "", pid: 0x2F)?.first {
            s.fuelPct = Double(a) * 100.0 / 255.0
        }
        s.voltage = parseVoltage(responses["ATRV"] ?? "")

        snapshot = s
        progress = 100
        message = "Vehicle scan complete"
        state = .finished
    }

    private func parsePID(_ raw: String, pid: UInt8) -> [UInt8]? {
        let bytes = hexBytes(raw)
        guard bytes.count >= 2 else { return nil }
        for i in 0..<(bytes.count - 1) where bytes[i] == 0x41 && bytes[i + 1] == pid {
            return Array(bytes.dropFirst(i + 2))
        }
        return nil
    }

    private func parseVIN(_ raw: String) -> String? {
        let bytes = hexBytes(raw)
        var payload: [UInt8] = []
        var i = 0
        while i + 2 < bytes.count {
            if bytes[i] == 0x49 && bytes[i + 1] == 0x02 {
                i += 3
                while i < bytes.count {
                    let b = bytes[i]
                    if b >= 0x20 && b <= 0x7E { payload.append(b) }
                    i += 1
                }
                break
            }
            i += 1
        }
        let vin = String(bytes: payload, encoding: .ascii)?.filter { $0.isLetter || $0.isNumber }
        guard let vin, vin.count >= 17 else { return nil }
        return String(vin.prefix(17))
    }

    private func parseDTCs(_ raw: String) -> [String] {
        let bytes = hexBytes(raw)
        guard let start = bytes.firstIndex(of: 0x43) else { return [] }
        let payload = Array(bytes.dropFirst(start + 1))
        var result: [String] = []
        var index = 0
        while index + 1 < payload.count {
            let a = payload[index], b = payload[index + 1]
            if a == 0 && b == 0 { break }
            let prefixes = ["P", "C", "B", "U"]
            let prefix = prefixes[Int((a & 0xC0) >> 6)]
            let firstDigit = Int((a & 0x30) >> 4)
            let second = String(format: "%X", a & 0x0F)
            let third = String(format: "%X", (b & 0xF0) >> 4)
            let fourth = String(format: "%X", b & 0x0F)
            result.append("\(prefix)\(firstDigit)\(second)\(third)\(fourth)")
            index += 2
        }
        return Array(Set(result)).sorted()
    }

    private func hexBytes(_ raw: String) -> [UInt8] {
        let cleaned = raw.uppercased()
            .replacingOccurrences(of: "SEARCHING...", with: "")
            .replacingOccurrences(of: "NO DATA", with: "")
            .replacingOccurrences(of: ">", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
        var bytes: [UInt8] = []
        for token in cleaned.split(whereSeparator: { $0 == " " || $0 == ":" || $0 == "\t" }) {
            let text = String(token)
            if text.count == 2, let value = UInt8(text, radix: 16) {
                bytes.append(value)
            } else if text.count > 2 && text.count.isMultiple(of: 2) && text.allSatisfy({ $0.isHexDigit }) {
                var cursor = text.startIndex
                while cursor < text.endIndex {
                    let end = text.index(cursor, offsetBy: 2)
                    if let value = UInt8(String(text[cursor..<end]), radix: 16) { bytes.append(value) }
                    cursor = end
                }
            }
        }
        return bytes
    }

    private func parseVoltage(_ raw: String) -> Double? {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*V"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
              let range = Range(match.range(at: 1), in: raw) else { return nil }
        return Double(raw[range])
    }

    private func label(for command: String) -> String {
        switch command {
        case "ATZ": return "Resetting OBDLink CX…"
        case "ATSP0": return "Detecting vehicle protocol…"
        case "0902": return "Reading VIN…"
        case "03": return "Reading engine trouble codes…"
        case "ATRV": return "Reading charging voltage…"
        default: return command.hasPrefix("01") ? "Reading live engine data…" : "Preparing diagnostic session…"
        }
    }

    private func fail(_ text: String) {
        central?.stopScan()
        timeout?.cancel()
        state = .failed(text)
        message = text
    }

    private func cleanup(keepCentral: Bool = true) {
        timeout?.cancel()
        timeout = nil
        queue.removeAll()
        currentCommand = nil
        responses.removeAll()
        receiveBuffer = ""
        writeCharacteristic = nil
        notifyCharacteristic = nil
        peripheral = nil
        if !keepCentral { central = nil }
    }
}
