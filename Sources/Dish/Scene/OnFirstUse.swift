// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

/// A value made the first time it is read, then kept. SwiftUI builds a
/// scene again on its own (a scene phase change does) and keeps only the
/// first build's `@State`; a scene that holds its composition root in one of
/// these makes the root once, in the build SwiftUI kept, and the builds it
/// throws away make nothing.
@MainActor
final class OnFirstUse<Value> {
    private let make: () -> Value
    private var made: Value?

    init(_ make: @escaping () -> Value) {
        self.make = make
    }

    var value: Value {
        if let made { return made }
        let fresh = make()
        made = fresh
        return fresh
    }
}
