// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Hands the newest object from the threads that post to the one thread that
/// reads it, without a lock. A post replaces, and releases, an object the
/// reader has not taken; a take moves the newest one out, so each object is
/// owned by the slot or by the reader and never by both. The reader's check
/// for mail is one relaxed load.
package final class Mailbox<Value: AnyObject & Sendable>: Sendable {
    private let slot = AtomicWord()

    package init() {}

    deinit {
        releaseObject(slot.exchange(0), as: Value.self)
    }

    /// True when the box was empty, so nothing the reader had not taken was
    /// replaced.
    @discardableResult
    package func post(_ value: Value) -> Bool {
        let replaced = slot.exchange(retainedBits(value))
        releaseObject(replaced, as: Value.self)
        return replaced == 0
    }

    package var hasMail: Bool {
        slot.loadRelaxed() != 0
    }

    /// The newest object posted since the last take, or nil.
    package func take() -> Value? {
        guard hasMail, let raw = UnsafeRawPointer(bitPattern: Int(slot.exchange(0))) else { return nil }
        return Unmanaged<Value>.fromOpaque(raw).takeRetainedValue()
    }
}

/// The one object a reader thread keeps after taking it from a mailbox. Only
/// that thread replaces it, so its reads borrow it without a retain race;
/// it is released when replaced and when the holder goes.
package final class ReaderHeld<Value: AnyObject & Sendable>: Sendable {
    private let slot = AtomicWord()

    package init() {}

    deinit {
        releaseObject(slot.exchange(0), as: Value.self)
    }

    /// The reader's own replace; the previous object is released.
    package func replace(with value: Value) {
        releaseObject(slot.exchange(retainedBits(value)), as: Value.self)
    }

    /// What the reader holds, read on the reader's thread.
    package var current: Value? {
        guard let raw = UnsafeRawPointer(bitPattern: Int(slot.loadRelaxed())) else { return nil }
        return Unmanaged<Value>.fromOpaque(raw).takeUnretainedValue()
    }
}

/// An object retained once and packed into a word.
private func retainedBits(_ value: some AnyObject) -> Int64 {
    Int64(Int(bitPattern: Unmanaged.passRetained(value).toOpaque()))
}

/// Releases the object a word holds; zero holds none.
private func releaseObject<Value: AnyObject>(_ bits: Int64, as _: Value.Type) {
    guard let raw = UnsafeRawPointer(bitPattern: Int(bits)) else { return }
    Unmanaged<Value>.fromOpaque(raw).release()
}
