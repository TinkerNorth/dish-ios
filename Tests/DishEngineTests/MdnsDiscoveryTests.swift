// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishEngine

/// The mDNS discovery surface: the TXT record read into a server, the
/// `source` field's exclusion from the wire format, and the merge by stable
/// id. dish-mac's two-path merge has one path here: the legacy beacon needs
/// the multicast entitlement.
final class MdnsDiscoveryTests: XCTestCase {

    // MARK: - The TXT record

    func testTheTxtRecordNamesThePortsAndTheMachineId() {
        let server = MdnsBrowser.makeServer(
            name: "Den PC",
            host: "10.0.0.5",
            txt: ["udp": "9900", "pair": "9443", "http": "9444", "mid": "abc"]
        )
        XCTAssertEqual(
            server,
            DiscoveredServer(name: "Den PC", ip: "10.0.0.5", udpPort: 9900, pairPort: 9443, httpPort: 9444, machineId: "abc")
        )
        XCTAssertEqual(server.id, "mid:abc")
    }

    func testAnEmptyTxtRecordTakesTheDefaultPortsAndTheAddressAsName() {
        let server = MdnsBrowser.makeServer(name: "", host: "10.0.0.5", txt: [:])
        XCTAssertEqual(server.name, "10.0.0.5")
        XCTAssertEqual(server.udpPort, defaultSatelliteUdpPort)
        XCTAssertEqual(server.httpPort, defaultSatelliteClientPort)
        XCTAssertEqual(server.id, "wifi:10.0.0.5:9876")
    }

    // MARK: - DiscoveredServer.source vs the wire format

    func testSourceIsNotEncodedToWire() throws {
        let server = DiscoveredServer(name: "sat", ip: "10.0.0.5", source: .manual)
        let data = try JSONEncoder().encode(server)
        let json = String(bytes: data, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("source"))
        let decoded = try JSONDecoder().decode(DiscoveredServer.self, from: data)
        XCTAssertEqual(decoded.source, .mdns)
    }

    // MARK: - mergeDiscovered

    private func server(_ name: String, _ ip: String, udp: Int = 9876) -> DiscoveredServer {
        DiscoveredServer(name: name, ip: ip, udpPort: udp, source: .manual)
    }

    func testMergeTagsEveryServerAsHeardOverBonjour() {
        let merged = mergeDiscovered([server("B", "10.0.0.2")])
        XCTAssertEqual(merged.map(\.source), [.mdns])
    }

    func testMergeCollapsesOneSatelliteHeardTwice() {
        XCTAssertEqual(mergeDiscovered([server("Sat", "10.0.0.9"), server("Sat", "10.0.0.9")]).count, 1)
    }

    func testMergeDistinguishesSameIpDifferentPort() {
        let merged = mergeDiscovered([server("One", "10.0.0.1", udp: 9876), server("Two", "10.0.0.1", udp: 9900)])
        XCTAssertEqual(merged.count, 2)
    }

    func testMergeSortsByName() {
        let merged = mergeDiscovered([server("Zulu", "10.0.0.3"), server("Alpha", "10.0.0.1"), server("Mike", "10.0.0.2")])
        XCTAssertEqual(merged.map(\.name), ["Alpha", "Mike", "Zulu"])
    }

    func testMergeEmptyInputsYieldEmptyResult() {
        XCTAssertTrue(mergeDiscovered([]).isEmpty)
    }

    // MARK: - A typed address

    func testATypedAddressIsAnIPv4LiteralWithAnOptionalPort() {
        XCTAssertEqual(DiscoveredServer.manual(from: " 192.168.1.40 "), DiscoveredServer(ip: "192.168.1.40", source: .manual))
        XCTAssertEqual(DiscoveredServer.manual(from: "192.168.1.40:9900")?.udpPort, 9900)
        XCTAssertNil(DiscoveredServer.manual(from: "den.local"))
        XCTAssertNil(DiscoveredServer.manual(from: "192.168.1.40:0"))
        XCTAssertNil(DiscoveredServer.manual(from: "192.168.1.40:1:2"))
        XCTAssertNil(DiscoveredServer.manual(from: ""))
    }
}
