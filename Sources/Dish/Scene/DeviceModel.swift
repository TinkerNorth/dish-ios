// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// The environment key the simulator names the simulated device under; a
/// device's environment has none.
let simulatedModelKey = "SIMULATOR_MODEL_IDENTIFIER"

/// The hardware's model identifier: the simulated device's when the
/// simulator names one, else the machine `uname` reports.
func hardwareModel(machine: String, simulated: String?) -> String {
    simulated ?? machine
}

/// The machine the kernel names in `uname`, a C string in a fixed tuple.
func unameMachine() -> String {
    var system = utsname()
    uname(&system)
    return withUnsafePointer(to: &system.machine) { machine in
        machine.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: machine.pointee)) { String(cString: $0) }
    }
}
