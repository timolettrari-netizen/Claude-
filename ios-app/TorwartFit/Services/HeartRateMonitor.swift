import Foundation
import CoreBluetooth

/// Live-Puls von einem Bluetooth-Brustgurt oder einer Uhr mit Herzfrequenz-Übertragung
/// (Standard-Profil „Heart Rate Service“ 0x180D – z. B. Polar H9/H10, Garmin HRM, Wahoo TICKR).
final class HeartRateMonitor: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = HeartRateMonitor()

    struct Device: Identifiable, Hashable { let id: UUID; let name: String }

    @Published var bpm: Int?
    @Published var lastUpdate: Date?
    @Published var connectedName: String?
    @Published var found: [Device] = []
    @Published var scanning = false
    @Published var bluetoothOff = false

    private let hrService = CBUUID(string: "180D")
    private let hrMeasurement = CBUUID(string: "2A37")
    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var connected: CBPeripheral?
    private var wantScan = false
    private let savedKey = "hr_device_uuid"

    /// Aktueller Puls, wenn er höchstens 5 Sekunden alt ist
    var liveBpm: Int? {
        guard let b = bpm, let t = lastUpdate, Date().timeIntervalSince(t) < 5 else { return nil }
        return b
    }

    private func ensureCentral() {
        if central == nil { central = CBCentralManager(delegate: self, queue: .main) }
    }

    /// Mit dem zuletzt gekoppelten Gerät verbinden (falls vorhanden)
    func start() {
        ensureCentral()
        reconnectSaved()
    }

    func scan() {
        ensureCentral()
        wantScan = true
        found = []
        if central?.state == .poweredOn { beginScan() }
    }

    func stopScan() {
        wantScan = false
        scanning = false
        central?.stopScan()
    }

    func connect(_ id: UUID) {
        guard let p = peripherals[id] else { return }
        stopScan()
        UserDefaults.standard.set(id.uuidString, forKey: savedKey)
        connected = p
        p.delegate = self
        central?.connect(p)
    }

    func disconnect() {
        if let p = connected { central?.cancelPeripheralConnection(p) }
        UserDefaults.standard.removeObject(forKey: savedKey)
        connected = nil
        connectedName = nil
        bpm = nil
    }

    private func beginScan() {
        scanning = true
        central?.scanForPeripherals(withServices: [hrService], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    private func reconnectSaved() {
        guard let c = central, c.state == .poweredOn, connected == nil,
              let s = UserDefaults.standard.string(forKey: savedKey), let id = UUID(uuidString: s),
              let p = c.retrievePeripherals(withIdentifiers: [id]).first else { return }
        peripherals[id] = p
        connected = p
        p.delegate = self
        c.connect(p)
    }

    // MARK: CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        bluetoothOff = c.state == .poweredOff
        guard c.state == .poweredOn else { return }
        if wantScan { beginScan() }
        reconnectSaved()
    }

    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        peripherals[p.identifier] = p
        let name = p.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "Pulsgurt"
        if !found.contains(where: { $0.id == p.identifier }) { found.append(Device(id: p.identifier, name: name)) }
    }

    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        connectedName = p.name ?? "Pulsgurt"
        p.discoverServices([hrService])
    }

    func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        // automatisch wieder verbinden, solange das Gerät gespeichert ist
        if UserDefaults.standard.string(forKey: savedKey) == p.identifier.uuidString { c.connect(p) }
    }

    // MARK: CBPeripheralDelegate

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        for s in p.services ?? [] where s.uuid == hrService { p.discoverCharacteristics([hrMeasurement], for: s) }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for ch in service.characteristics ?? [] where ch.uuid == hrMeasurement { p.setNotifyValue(true, for: ch) }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        guard ch.uuid == hrMeasurement, let data = ch.value, data.count >= 2 else { return }
        let bytes = [UInt8](data)
        let value: Int
        if bytes[0] & 0x01 == 0 { value = Int(bytes[1]) }
        else if bytes.count >= 3 { value = Int(bytes[1]) | (Int(bytes[2]) << 8) }
        else { return }
        guard value > 25, value < 240 else { return }
        bpm = value
        lastUpdate = Date()
    }
}
