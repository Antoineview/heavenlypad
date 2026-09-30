// HeavenlyPad/Core/BIOS/BIOSHLE.swift
// High-Level Emulation of BIOS SWI calls

import Foundation

final class BIOSHLE {
    
    // MARK: - ARM9 SWI Handler
    
    func handleSWI9(_ number: UInt8, cpu: CPUState, bus: Bus) {
        switch number {
        case 0x03: // WaitByLoop
            cpu.halted = true
        case 0x04: // IntrWait
            let discardOldFlags = cpu.r[0]
            let irqMask = cpu.r[1]
            if discardOldFlags != 0 {
                // bus.io9.IF &= ~irqMask
            }
            cpu.halted = true
            // In a real implementation, we'd check if the IRQ is already pending here
        case 0x05: // VBlankIntrWait
            cpu.r[0] = 1
            cpu.r[1] = 1 // VBlank flag is bit 0
            handleSWI9(0x04, cpu: cpu, bus: bus)
        case 0x06: // Halt
            cpu.halted = true
        case 0x09: // Div
            let num = Int32(bitPattern: cpu.r[0])
            let den = Int32(bitPattern: cpu.r[1])
            if den == 0 {
                cpu.r[0] = UInt32(bitPattern: num >= 0 ? Int32.max : Int32.min)
                cpu.r[1] = UInt32(bitPattern: num)
            } else {
                cpu.r[0] = UInt32(bitPattern: num / den)
                cpu.r[1] = UInt32(bitPattern: num % den)
            }
        case 0x0B: // CpuSet
            let src = cpu.r[0]
            var dst = cpu.r[1]
            let cnt = cpu.r[2]
            let wordCount = cnt & 0x1F_FFFF
            let is32Bit = (cnt & (1 << 26)) != 0
            let fill = (cnt & (1 << 24)) != 0
            
            if is32Bit {
                let val = bus.read32ARM9(src)
                for i in 0..<wordCount {
                    bus.write32ARM9(dst, value: fill ? val : bus.read32ARM9(src &+ (UInt32(i) * 4)))
                    dst &+= 4
                }
            } else {
                let val = bus.read16ARM9(src)
                for i in 0..<wordCount {
                    bus.write16ARM9(dst, value: fill ? val : bus.read16ARM9(src &+ (UInt32(i) * 2)))
                    dst &+= 2
                }
            }
        case 0x0C: // CpuFastSet
            let src = cpu.r[0]
            var dst = cpu.r[1]
            let cnt = cpu.r[2]
            let wordCount = (cnt & 0x1F_FFFF) * 8 // 8 words (32 bytes) at a time
            let fill = (cnt & (1 << 24)) != 0
            
            let val = bus.read32ARM9(src)
            for i in 0..<wordCount {
                bus.write32ARM9(dst, value: fill ? val : bus.read32ARM9(src &+ (i * 4)))
                dst &+= 4
            }
        default:
            print(String(format: "Unhandled SWI9: 0x%02X", number))
        }
    }
    
    // MARK: - ARM7 SWI Handler
    
    func handleSWI7(_ number: UInt8, cpu: CPUState, bus: Bus) {
        switch number {
        case 0x03: cpu.halted = true
        case 0x04:
            let discardOldFlags = cpu.r[0]
            let irqMask = cpu.r[1]
            if discardOldFlags != 0 {
                bus.io7.write32(0x04000214, value: bus.io7.read32(0x04000214) & ~irqMask) // IF
            }
            cpu.halted = true
        case 0x05:
            cpu.r[0] = 1
            cpu.r[1] = 1
            handleSWI7(0x04, cpu: cpu, bus: bus)
        case 0x06: cpu.halted = true
        case 0x09:
            let num = Int32(bitPattern: cpu.r[0])
            let den = Int32(bitPattern: cpu.r[1])
            if den == 0 {
                cpu.r[0] = UInt32(bitPattern: num >= 0 ? Int32.max : Int32.min)
                cpu.r[1] = UInt32(bitPattern: num)
            } else {
                cpu.r[0] = UInt32(bitPattern: num / den)
                cpu.r[1] = UInt32(bitPattern: num % den)
            }
        case 0x0B: // CpuSet
            let src = cpu.r[0]
            var dst = cpu.r[1]
            let cnt = cpu.r[2]
            let wordCount = cnt & 0x1F_FFFF
            let is32Bit = (cnt & (1 << 26)) != 0
            let fill = (cnt & (1 << 24)) != 0
            
            if is32Bit {
                let val = bus.read32ARM7(src)
                for i in 0..<wordCount {
                    bus.write32ARM7(dst, value: fill ? val : bus.read32ARM7(src &+ (UInt32(i) * 4)))
                    dst &+= 4
                }
            } else {
                let val = bus.read16ARM7(src)
                for i in 0..<wordCount {
                    bus.write16ARM7(dst, value: fill ? val : bus.read16ARM7(src &+ (UInt32(i) * 2)))
                    dst &+= 2
                }
            }
        case 0x0C: // CpuFastSet
            let src = cpu.r[0]
            var dst = cpu.r[1]
            let cnt = cpu.r[2]
            let wordCount = (cnt & 0x1F_FFFF) * 8
            let fill = (cnt & (1 << 24)) != 0
            
            let val = bus.read32ARM7(src)
            for i in 0..<wordCount {
                bus.write32ARM7(dst, value: fill ? val : bus.read32ARM7(src &+ (i * 4)))
                dst &+= 4
            }
        default:
            print(String(format: "Unhandled SWI7: 0x%02X", number))
        }
    }
}
