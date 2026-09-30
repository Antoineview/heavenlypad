// HeavenlyPad/Core/Emulator.swift

import Foundation
import AppKit

final class Emulator {
    let bus = Bus()
    let cpu9 = CPUState()
    let cpu7 = CPUState()
    let touchscreen = Touchscreen()
    lazy var gpu = GPU(bus: bus)
    let audioEngine = AudioEngine()
    var frontend: LibretroFrontend?
    private var isReady = false
    private let lock = NSLock()
    private var terminationObserver: NSObjectProtocol?

    init() {
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.shutdown()
        }
    }

    deinit {
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
        shutdown()
    }
    
    func boot(romURL: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        frontend = LibretroFrontend(emulator: self)
        try frontend?.load(romURL: romURL)
        audioEngine.start()
        isReady = true
    }
    
    func executeFrame() {
        lock.lock()
        defer { lock.unlock() }
        if isReady {
            frontend?.runFrame()
        }
    }

    func shutdown() {
        lock.lock()
        defer { lock.unlock() }
        guard frontend != nil || isReady else { return }

        isReady = false
        touchscreen.isPressed = false
        audioEngine.stop()
        frontend?.close()
        frontend = nil
    }
}
