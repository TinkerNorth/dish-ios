// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import CoreBluetooth
import DishCore
import Foundation

/// CoreBluetooth's central for the Steam Controllers, driven as SDL's iOS
/// backend drives it (`src/hidapi/ios/hid.m`): made on the links' queue when
/// the person opts in, every callback delivered on that queue, and the
/// paired pads found among the peripherals the system has connected. It is
/// confined to the queue. iOS sizes the MTU itself; a 2026 pad's 45-byte
/// notification arrives whole, and every write is with response, which
/// CoreBluetooth splits as the MTU needs.
final class CoreBluetoothRadio: NSObject, SteamRadio {
    private let events: any SteamRadioEvents
    private let central: CBCentralManager
    private let valveService = CBUUID(string: SteamBleUuid.service)
    /// SDL retrieves by the Device Information service; Valve's own is
    /// asked for beside it, and either serves a paired pad.
    private let retrieved = [CBUUID(string: SteamBleUuid.service), CBUUID(string: SteamBleUuid.deviceInformation)]
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var characteristics: [UUID: [String: CBCharacteristic]] = [:]
    private var inputs: [UUID: CBCharacteristic] = [:]

    /// The row says when Bluetooth is off, so iOS's own alert stays down.
    init(events: any SteamRadioEvents, queue: DispatchSerialQueue) {
        self.events = events
        central = CBCentralManager(delegate: nil, queue: queue, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        super.init()
        central.delegate = self
    }

    func connectedSteamControllers() -> [UUID] {
        let steam = central.retrieveConnectedPeripherals(withServices: retrieved).filter { isSteamControllerName($0.name) }
        for peripheral in steam {
            keep(peripheral)
        }
        return steam.map(\.identifier)
    }

    func connect(_ pad: UUID) {
        guard let peripheral = peripherals[pad] else { return }
        central.connect(peripheral, options: nil)
    }

    func disconnect(_ pad: UUID) {
        guard let peripheral = forget(pad) else { return }
        central.cancelPeripheralConnection(peripheral)
    }

    func discoverServices(of pad: UUID) {
        peripherals[pad]?.discoverServices([valveService])
    }

    func discoverCharacteristics(of pad: UUID) {
        guard let peripheral = peripherals[pad],
              let service = peripheral.services?.first(where: { $0.uuid == valveService }) else { return }
        peripheral.discoverCharacteristics(nil, for: service)
    }

    func subscribe(_ pad: UUID, to characteristic: String) {
        guard let peripheral = peripherals[pad], let input = characteristics[pad]?[characteristic] else { return }
        inputs[pad] = input
        peripheral.setNotifyValue(true, for: input)
    }

    func write(_ value: [UInt8], to characteristic: String, of pad: UUID) {
        guard let peripheral = peripherals[pad], let target = characteristics[pad]?[characteristic] else { return }
        peripheral.writeValue(Data(value), for: target, type: .withResponse)
    }

    func close() {
        central.delegate = nil
        for pad in Array(peripherals.keys) {
            disconnect(pad)
        }
    }

    private func keep(_ peripheral: CBPeripheral) {
        guard peripherals[peripheral.identifier] == nil else { return }
        peripheral.delegate = self
        peripherals[peripheral.identifier] = peripheral
    }

    private func forget(_ pad: UUID) -> CBPeripheral? {
        characteristics.removeValue(forKey: pad)
        inputs.removeValue(forKey: pad)
        return peripherals.removeValue(forKey: pad)
    }

    private func forgetAll() {
        peripherals.removeAll()
        characteristics.removeAll()
        inputs.removeAll()
    }

    /// A pad the system connects again is found and kept afresh.
    private func lose(_ pad: UUID) {
        _ = forget(pad) // Its connection is gone already; only the objects go.
        events.lost(pad)
    }
}

extension CoreBluetoothRadio: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = steamRadioState(central.state, authorization: CBManager.authorization)
        if !steamRadioKeepsPeripherals(state) { forgetAll() }
        events.radioChanged(state)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        events.connected(peripheral.identifier)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        lose(peripheral.identifier)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        lose(peripheral.identifier)
    }
}

extension CoreBluetoothRadio: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        let valve = peripheral.services?.contains { $0.uuid == valveService } == true
        events.servicesFound(peripheral.identifier, valve: error == nil && valve)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        let found = service.characteristics ?? []
        characteristics[peripheral.identifier] = Dictionary(found.map { ($0.uuid.uuidString, $0) }) { _, last in last }
        events.characteristicsFound(peripheral.identifier, found.map(\.uuid.uuidString))
    }

    /// Only the input the pad was subscribed to reaches the decoder.
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        guard error == nil, characteristic === inputs[peripheral.identifier], let value = characteristic.value else { return }
        events.received(value, from: peripheral.identifier)
    }
}

/// CoreBluetooth's state as the links read it; an unauthorized central is
/// told apart by whether the person can lift the refusal.
func steamRadioState(_ state: CBManagerState, authorization: CBManagerAuthorization) -> SteamRadioState {
    switch state {
    case .poweredOn: .poweredOn
    case .poweredOff: .poweredOff
    case .unsupported: .unsupported
    case .unauthorized: authorization == .restricted ? .restricted : .denied
    case .unknown, .resetting: .waiting
    @unknown default: .waiting
    }
}
