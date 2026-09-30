// HeavenlyPad/Core/Memory/VRAMController.swift
import Foundation

final class VRAMController {
    func read8ARM9(_ address: UInt32) -> UInt8 { return 0 }
    func read16ARM9(_ address: UInt32) -> UInt16 { return 0 }
    func read32ARM9(_ address: UInt32) -> UInt32 { return 0 }
    
    func write8ARM9(_ address: UInt32, value: UInt8) {}
    func write16ARM9(_ address: UInt32, value: UInt16) {}
    func write32ARM9(_ address: UInt32, value: UInt32) {}

    func read8ARM7(_ address: UInt32) -> UInt8 { return 0 }
    func read16ARM7(_ address: UInt32) -> UInt16 { return 0 }
    func read32ARM7(_ address: UInt32) -> UInt32 { return 0 }
    
    func write8ARM7(_ address: UInt32, value: UInt8) {}
    func write16ARM7(_ address: UInt32, value: UInt16) {}
    func write32ARM7(_ address: UInt32, value: UInt32) {}
}
