// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishKernel
import Foundation

/// The controller data in force and its check against the website: the
/// bundled copy, or the cached download when it is newer; a check ten
/// seconds after launch and every six hours while the app is in the
/// foreground, or when the person asks; nothing at all while the switch is
/// off. The decisions are the core's (`controllerDbGate`, `manifestStep`,
/// `installStep`, `controllerDbCheckDelayMs`); this store performs the
/// requests they name, swaps the cache whole and says what happened.
@MainActor
package final class ControllerDbStore {
    private let bundled: ControllerDbSet
    private let cache: ControllerDbCache
    private let gateway: any ControllerDbGateway
    private let preferences: ControllerDbPreferenceStore
    private let ticker: any Ticker
    private let now: @MainActor () -> Int64
    private let indexSource: StateSource<ControllerIndex>
    private let checking = StateSource<Bool>(initial: false)
    /// When a check last ran in this run of the app; the schedule counts
    /// from it.
    private var lastCheckThisRunMs: Int64?
    private var scheduled = false
    private var inFlight: Task<Void, Never>?

    package init(
        bundled: ControllerDbSet,
        cache: ControllerDbCache,
        gateway: any ControllerDbGateway,
        preferences: ControllerDbPreferenceStore,
        ticker: any Ticker,
        now: @escaping @MainActor () -> Int64 = wallClockMilliseconds
    ) {
        self.bundled = bundled
        self.cache = cache
        self.gateway = gateway
        self.preferences = preferences
        self.ticker = ticker
        self.now = now
        indexSource = StateSource(initial: activeControllerIndex(bundled: bundled, cached: cache.load()))
    }

    /// The index the controllers' facts read their records from.
    package var index: ControllerIndex {
        indexSource.state
    }

    /// What Settings and Diagnostics show.
    package var status: ControllerDbStatus {
        let preferences = preferences.state
        return ControllerDbStatus(
            bundledVersion: bundled.dbVersion,
            activeVersion: index.dbVersion,
            source: index.source,
            checksEnabled: preferences.checksEnabled,
            lastCheckAtMs: preferences.lastCheckAtMs,
            lastCheckResult: preferences.lastCheckResult,
            checking: checking.state
        )
    }

    // MARK: - The schedule

    /// The app is in the foreground: the next check is armed, ten seconds
    /// out at launch and six hours after the last one after that.
    package func resume() {
        scheduled = true
        arm()
    }

    /// The app left the foreground: nothing is armed until it comes back.
    package func pause() {
        scheduled = false
        ticker.stop()
    }

    package func setChecksEnabled(_ enabled: Bool) {
        preferences.setChecksEnabled(enabled)
        guard enabled else { return switchedOff() }
        arm()
    }

    /// One check now, whatever the schedule; with the switch off nothing is
    /// sent and the check reads off.
    package func checkNow() {
        run()
    }

    /// The check in flight, for a test to wait on.
    func settle() async {
        await inFlight?.value
    }

    private func arm() {
        ticker.stop()
        guard scheduled, preferences.state.checksEnabled else { return }
        let delayMs = controllerDbCheckDelayMs(lastCheckThisRunMs: lastCheckThisRunMs, nowMs: now())
        ticker.start(every: TimeInterval(delayMs) / 1000, due)
    }

    private func due() {
        ticker.stop()
        run()
    }

    private func switchedOff() {
        ticker.stop()
        preferences.recordCheck(.off, atMs: now())
    }

    // MARK: - One check

    private func run() {
        switch controllerDbGate(checksEnabled: preferences.state.checksEnabled) {
        case let .stay(result): finish(result)
        case .ask: ask()
        }
    }

    private func ask() {
        guard inFlight == nil else { return }
        checking.setState(true)
        inFlight = Task { [weak self] in
            guard let self else { return }
            let result = await check()
            inFlight = nil
            checking.setState(false)
            finish(result)
        }
    }

    private func check() async -> ControllerDbCheckResult {
        let reply = await gateway.manifest(etag: preferences.state.etag)
        switch manifestStep(reply, activeVersion: index.dbVersion) {
        case let .done(result):
            keepETag(of: reply, after: result)
            return result
        case let .download(manifest):
            return await download(manifest, reply: reply)
        }
    }

    /// A manifest that told us nothing new is the one to ask about next time.
    private func keepETag(of reply: ManifestReply, after result: ControllerDbCheckResult) {
        guard case let .body(_, etag) = reply, result == .upToDate else { return }
        preferences.setEtag(etag)
    }

    private func download(_ manifest: ControllerDbManifest, reply: ManifestReply) async -> ControllerDbCheckResult {
        let files = await fetchAll(manifest)
        switch installStep(manifest: manifest, files: files) {
        case let .done(result): return result
        case let .install(set): return install(set, files: files ?? [:], reply: reply)
        }
    }

    /// Every file the manifest names, or nil when one did not arrive.
    private func fetchAll(_ manifest: ControllerDbManifest) async -> [String: Data]? {
        var files: [String: Data] = [:]
        for path in manifest.files.keys.sorted() {
            guard let data = await gateway.file(path) else { return nil }
            files[path] = data
        }
        return files
    }

    /// The manifest's own bytes are stored with the files it vouches for; a
    /// swap that fails leaves the old set and reads as invalid.
    private func install(_ set: ControllerDbSet, files: [String: Data], reply: ManifestReply) -> ControllerDbCheckResult {
        guard case let .body(body, etag) = reply else { return .invalid }
        var stored = files
        stored[ControllerDbFiles.manifest] = body
        guard cache.replaceAll(stored) else { return .invalid }
        preferences.setEtag(etag)
        indexSource.setState(activeControllerIndex(bundled: bundled, cached: set))
        return .updated
    }

    private func finish(_ result: ControllerDbCheckResult) {
        let at = now()
        lastCheckThisRunMs = at
        preferences.recordCheck(result, atMs: at)
        arm()
    }
}
