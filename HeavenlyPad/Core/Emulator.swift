// HeavenlyPad/Core/Emulator.swift

import Foundation

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
}
