// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Dumb, synchronous keyed storage, the kernel's shape from the siblings: a
/// repository decides nothing, and a store that holds one keeps what it
/// read in a `StateSource` for the UI.
package protocol Repository<Key, Value> {
    associatedtype Key: Hashable
    associatedtype Value

    func get(_ key: Key) -> Value?
    func all() -> [Value]
    func put(_ value: Value, for key: Key)
    func remove(_ key: Key)
    func clear()
}
