// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import GameController
import Observation
import os

/// Bridges GameController.framework into the input processor: one full
/// report per value change, plus the motion, touchpad and battery streams,
/// and the rumble, light-bar, trigger and player-index return paths. A
/// controller without the extended profile is listed as unreadable and not
/// read: iOS gives apps no HID access, so dish-mac's profile and Direct
/// paths have no counterpart here.
@MainActor
@Observable
package final class GameControllerInput: ControllerSource {
    nonisolated static let log = Logger(subsystem: "com.tinkernorth.dish", category: "GC")

    package private(set) var slots: [ControllerSlot] = []

    package let processor: GamepadInputProcessor
    /// The pads' feedback: posted from any thread, actuated on its own queue.
    package let feedback: PadFeedback
    /// What the feedback queue drives; touched only on that queue.
    let padActuators: PadActuators
    /// Drives the battery cadence once a second while a pad is attached.
    @ObservationIgnored let batteryTicker: any Ticker
    /// The iPhone's or iPad's own battery, which competes with each pad's.
    @ObservationIgnored let deviceBattery: any DeviceBattery
    /// Each pad's seconds since it attached and its last forwarded charge
    /// state, for the battery cadence.
    @ObservationIgnored var batteryClocks: [String: Int] = [:]
    @ObservationIgnored var lastBatteryState: [String: BatteryChargeState] = [:]
    @ObservationIgnored var controllersById: [String: GCController] = [:]

    /// Each controller's handlers run on a serial queue of its own, so the
    /// hot path never waits behind the main thread or another pad; one per
    /// slot id, kept across a re-attach, so a pad's feed has one thread.
    @ObservationIgnored private var handlerQueues: [String: DispatchSerialQueue] = [:]
    @ObservationIgnored private var controllerIds: [ObjectIdentifier: String] = [:]
    @ObservationIgnored private var observers: [NotificationCenter.ObservationToken] = []
    @ObservationIgnored private let center: NotificationCenter

    /// `connected` is the launch sweep, the framework's list unless a test
    /// hands in its own; `center` carries the connect and disconnect messages;
    /// `deviceBattery` is the scene's.
    package init(
        connected: [GCController] = GCController.controllers(),
        center: NotificationCenter = .default,
        batteryTicker: any Ticker = TimerTicker(),
        deviceBattery: any DeviceBattery = InertDeviceBattery()
    ) {
        let actuators = PadActuators(queue: ThreadRole.feedback.queue(label: "dish.feedback", qos: .userInteractive))
        padActuators = actuators
        feedback = PadFeedback(actuators: actuators, queue: actuators.queue)
        processor = GamepadInputProcessor()
        self.center = center
        self.batteryTicker = batteryTicker
        self.deviceBattery = deviceBattery
        observers.append(center.addObserver(of: GCController.self, for: .didConnect) { [weak self] message in
            self?.attach(message.controller)
        })
        observers.append(center.addObserver(of: GCController.self, for: .didDisconnect) { [weak self] message in
            self?.detach(message.controller)
        })
        for controller in connected {
            attach(controller)
        }
    }

    isolated deinit {
        for observer in observers {
            center.removeObserver(observer)
        }
        batteryTicker.stop()
    }

    // MARK: - Attach / detach

    /// The queue is the controller's before any handler is, so no event
    /// lands on the main queue first. A pad without the extended profile is
    /// listed and left alone.
    package func attach(_ controller: GCController) {
        let id = slotId(for: controller)
        guard let pad = controller.extendedGamepad else {
            recordSlot(ControllerSlot(id: id, name: Self.name(of: controller), link: Self.link(of: controller), readable: false))
            return
        }
        let feed = processor.feed(for: id)
        controller.handlerQueue = handlerQueue(for: id)
        recordSlot(ControllerSlot(
            id: id,
            name: Self.name(of: controller),
            link: Self.link(of: controller),
            capabilities: Self.detectCapabilities(controller, pad: pad),
            family: Self.family(of: controller)
        ))
        Self.installReportHandler(pad: pad, feed: feed)
        Self.installMotionHandler(controller: controller, feed: feed)
        Self.installTouchpadHandlers(pad: pad, feed: feed)
        startBatteryClock(deviceId: id)
    }

    package func detach(_ controller: GCController) {
        guard let id = controllerIds.removeValue(forKey: ObjectIdentifier(controller)) else { return }
        controller.extendedGamepad?.valueChangedHandler = nil
        controller.motion?.valueChangedHandler = nil
        if let pad = controller.extendedGamepad, let touchpad = Self.touchpadInputs(pad) {
            touchpad.primary.valueChangedHandler = nil
            touchpad.secondary.valueChangedHandler = nil
            touchpad.button.valueChangedHandler = nil
        }
        slots.removeAll { $0.id == id }
        processor.remove(deviceId: id)
        fileController(nil, for: id)
        stopBatteryClock(deviceId: id)
    }

    /// The handler queue a slot's controller was handed.
    package func handlerQueue(for id: String) -> DispatchSerialQueue {
        if let queue = handlerQueues[id] { return queue }
        let queue = ThreadRole.input.queue(label: "com.tinkernorth.dish.input.\(id)", qos: .userInteractive)
        handlerQueues[id] = queue
        return queue
    }

    func updateBattery(_ reading: BatteryReading, at index: Int) {
        slots[index].battery = reading
    }

    /// A re-attach replaces the slot in place, so the list keeps its order.
    private func recordSlot(_ slot: ControllerSlot) {
        if let index = slots.firstIndex(where: { $0.id == slot.id }) {
            slots[index] = slot
        } else {
            slots.append(slot)
        }
        Self.log.info("""
        DEVCAPS id=\(slot.id, privacy: .public) family=\(String(describing: slot.family), privacy: .public) \
        readable=\(slot.readable) motion=\(slot.capabilities.hasMotion) touchpad=\(slot.capabilities.hasTouchpad) \
        rumble=\(slot.capabilities.hasRumble) lightbar=\(slot.capabilities.hasLightbar) \
        battery=\(slot.capabilities.hasBattery) triggerEffects=\(slot.capabilities.hasTriggerEffects) \
        playerLeds=\(slot.capabilities.hasPlayerLeds) extendedButtons=\(slot.capabilities.hasExtendedButtons)
        """)
    }

    /// Only the DualSense takes trigger effects and has player LEDs the
    /// framework drives by player index; only an Xbox Elite has paddles.
    private static func detectCapabilities(_ controller: GCController, pad: GCExtendedGamepad) -> ControllerCapabilities {
        let dualSense = pad is GCDualSenseGamepad
        return ControllerCapabilities(
            hasMotion: controller.motion != nil,
            hasTouchpad: touchpadInputs(pad) != nil,
            hasRumble: controller.haptics != nil,
            hasLightbar: controller.light != nil,
            hasBattery: controller.battery != nil,
            hasTriggerEffects: dualSense,
            hasPlayerLeds: dualSense,
            hasExtendedButtons: paddleInputs(pad) != nil
        )
    }

    static func family(of controller: GCController) -> PadFamily {
        padFamily(productCategory: controller.productCategory, vendorName: controller.vendorName)
    }

    /// The vendor's name, or the product category for a pad that names none.
    static func name(of controller: GCController) -> String {
        controller.vendorName ?? controller.productCategory
    }

    /// GameController tells an app one thing about the transport: whether
    /// the pad is attached to the device (a clip-on such as a Backbone). That
    /// pad is plugged in; every other pad is on Bluetooth as far as iOS says.
    static func link(of controller: GCController) -> PadLink {
        controller.isAttachedToDevice ? .usbC : .bluetooth
    }

    /// Only the DualSense and DualShock 4 profiles expose a touchpad.
    nonisolated static func touchpadInputs(_ pad: GCExtendedGamepad) -> TouchpadInputs? {
        if let dualSense = pad as? GCDualSenseGamepad {
            return TouchpadInputs(
                primary: dualSense.touchpadPrimary,
                secondary: dualSense.touchpadSecondary,
                button: dualSense.touchpadButton
            )
        }
        if let dualShock = pad as? GCDualShockGamepad {
            return TouchpadInputs(
                primary: dualShock.touchpadPrimary,
                secondary: dualShock.touchpadSecondary,
                button: dualShock.touchpadButton
            )
        }
        return nil
    }

    struct TouchpadInputs {
        let primary: GCControllerDirectionPad
        let secondary: GCControllerDirectionPad
        let button: GCControllerButtonInput
    }

    // MARK: - Hot path

    /// GameController coalesces simultaneous changes into one call, and the
    /// handler rebuilds the whole report from the pad every time, with the
    /// paddles found once here. Nonisolated, so the compiler refuses a
    /// handler that reaches for main-actor state: it runs on the input queue.
    private nonisolated static func installReportHandler(pad: GCExtendedGamepad, feed: PadFeed) {
        let paddles = paddleInputs(pad)
        pad.valueChangedHandler = { pad, _ in
            pushReport(pad: pad, paddles: paddles, feed: feed)
        }
    }

    nonisolated static func pushReport(pad: GCExtendedGamepad, paddles: PaddleInputs?, feed: PadFeed) {
        feed.publishIfChanged(wireReport(padSample(pad, paddles: paddles)))
    }

    /// The pad as GameController reads it, which is already the wire's
    /// orientation: both report a stick pushed up as positive y.
    nonisolated static func padSample(_ pad: GCExtendedGamepad, paddles: PaddleInputs? = nil) -> PadSample {
        PadSample(
            leftX: pad.leftThumbstick.xAxis.value,
            leftY: pad.leftThumbstick.yAxis.value,
            rightX: pad.rightThumbstick.xAxis.value,
            rightY: pad.rightThumbstick.yAxis.value,
            leftTrigger: pad.leftTrigger.value,
            rightTrigger: pad.rightTrigger.value,
            pressed: heldButtons(pad),
            extButtons: heldPaddles(paddles)
        )
    }

    /// The fleet's button table, read off the pad's named inputs one by one:
    /// no table of key paths is walked and nothing is built. XUSB has no
    /// Share button and no paddles: the paddles ride the extended-buttons
    /// word, and the Share button stays unmapped.
    nonisolated static func heldButtons(_ pad: GCExtendedGamepad) -> WireButtonWord {
        var word = WireButtonWord()
        word.insert(.faceA, held: pad.buttonA.isPressed)
        word.insert(.faceB, held: pad.buttonB.isPressed)
        word.insert(.faceX, held: pad.buttonX.isPressed)
        word.insert(.faceY, held: pad.buttonY.isPressed)
        word.insert(.leftShoulder, held: pad.leftShoulder.isPressed)
        word.insert(.rightShoulder, held: pad.rightShoulder.isPressed)
        word.insert(.start, held: pad.buttonMenu.isPressed)
        word.insert(.dpadUp, held: pad.dpad.up.isPressed)
        word.insert(.dpadDown, held: pad.dpad.down.isPressed)
        word.insert(.dpadLeft, held: pad.dpad.left.isPressed)
        word.insert(.dpadRight, held: pad.dpad.right.isPressed)
        word.insert(.back, held: pad.buttonOptions?.isPressed == true)
        word.insert(.guide, held: pad.buttonHome?.isPressed == true)
        word.insert(.leftThumb, held: pad.leftThumbstickButton?.isPressed == true)
        word.insert(.rightThumb, held: pad.rightThumbstickButton?.isPressed == true)
        return word
    }

    // MARK: - Identity

    nonisolated static let slotIdPrefix = "gc:"
    nonisolated static let unknownVendor = "unknown"

    /// The launch sweep and the connect message can both name one pad; the
    /// same object keeps its id so a re-attach never reads as a second pad.
    package func slotId(for controller: GCController) -> String {
        let id = controllerIds[ObjectIdentifier(controller)] ?? stableId(for: controller)
        controllerIds[ObjectIdentifier(controller)] = id
        fileController(controller, for: id)
        return id
    }

    /// GameController vends a fresh object on every reconnect and exposes no
    /// per-unit identifier, so the id is the vendor name and product
    /// category, which survive a replug. Two identical pads get the lowest
    /// free ordinal.
    private func stableId(for controller: GCController) -> String {
        let vendor = controller.vendorName ?? Self.unknownVendor
        let base = "\(Self.slotIdPrefix)\(vendor):\(controller.productCategory)"
        return lowestFreeSlotId(base: base, taken: Set(controllerIds.values))
    }
}

extension WireButtonWord {
    /// Sets the button's bit when it is held.
    mutating func insert(_ button: WireButton, held: Bool) {
        if held { insert(button) }
    }
}

/// The family a product category names: the framework's three constants,
/// then Nintendo's pads by their words, else a generic pad.
func padFamily(productCategory: String, vendorName: String?) -> PadFamily {
    switch productCategory {
    case GCProductCategoryDualSense: .dualSense
    case GCProductCategoryDualShock4: .dualShock4
    case GCProductCategoryXboxOne: .xbox
    default: namedPadFamily(productCategory: productCategory, vendorName: vendorName)
    }
}

/// The base when it is free, else the lowest free `#n`.
func lowestFreeSlotId(base: String, taken: Set<String>) -> String {
    guard taken.contains(base) else { return base }
    var ordinal = 1
    while taken.contains("\(base)#\(ordinal)") {
        ordinal += 1
    }
    return "\(base)#\(ordinal)"
}

/// The name a pad is listed under, read back from its slot id when the pad
/// is not attached: the vendor's name, or the product category for a pad
/// that names no vendor.
package func padName(fromSlotId slotId: String) -> String {
    guard slotId.hasPrefix(GameControllerInput.slotIdPrefix), let split = slotId.lastIndex(of: ":") else { return slotId }
    let vendor = String(slotId[slotId.index(slotId.startIndex, offsetBy: GameControllerInput.slotIdPrefix.count) ..< split])
    let category = String(slotId[slotId.index(after: split)...].prefix { $0 != "#" })
    return vendor == GameControllerInput.unknownVendor ? category : vendor
}
