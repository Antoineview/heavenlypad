// HeavenlyPad/Core/Memory/IORegisters7.swift
import Foundation

final class IORegisters7 {
    func read8(_ address: UInt32) -> UInt8 { return 0 }
    func read16(_ address: UInt32) -> UInt16 { return 0 }
    func read32(_ address: UInt32) -> UInt32 { return 0 }
    
    func write8(_ address: UInt32, value: UInt8) {}
    func write16(_ address: UInt32, value: UInt16) {}
    func write32(_ address: UInt32, value: UInt32) {}
}
