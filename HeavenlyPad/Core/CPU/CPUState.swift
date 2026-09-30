// HeavenlyPad/Core/CPU/CPUState.swift
// ARM CPU register state and mode management

import Foundation

/// ARM processor operating modes (CPSR bits 4:0)
enum ARMMode: UInt8, Sendable {
    case user       = 0x10
    case fiq        = 0x11
    case irq        = 0x12
    case supervisor = 0x13
    case abort      = 0x17
    case undefined  = 0x1B
    case system     = 0x1F
}

/// Complete ARM CPU register state
/// Used for both ARM9 (ARMv5TE) and ARM7 (ARMv4T)
final class CPUState {
    /// General purpose registers R0-R15
    /// R13 = SP, R14 = LR, R15 = PC
    var r: [UInt32] = [UInt32](repeating: 0, count: 16)

    /// Current Program Status Register
    var cpsr: UInt32 = UInt32(ARMMode.system.rawValue)

    /// Banked SP (R13) per mode
    var bankedSP: [UInt8: UInt32] = [:]

    /// Banked LR (R14) per mode
    var bankedLR: [UInt8: UInt32] = [:]

    /// Saved Program Status Register per mode
    var spsr: [UInt8: UInt32] = [:]

    /// FIQ-banked R8-R12
    var fiqR8_12: [UInt32] = [UInt32](repeating: 0, count: 5)
    /// User/System R8-R12 (saved when entering FIQ)
    var usrR8_12: [UInt32] = [UInt32](repeating: 0, count: 5)

    /// CPU halted (waiting for interrupt via SWI Halt/VBlankIntrWait)
    var halted: Bool = false

    /// IRQ line asserted
    var irqPending: Bool = false

    /// Cycle counter for current execution slice
    var cycles: Int = 0

    // MARK: - Convenience Accessors

    var pc: UInt32 {
        get { r[15] }
        set { r[15] = newValue }
    }

    var sp: UInt32 {
        get { r[13] }
        set { r[13] = newValue }
    }

    var lr: UInt32 {
        get { r[14] }
        set { r[14] = newValue }
    }

    // MARK: - CPSR Flag Accessors

    /// Negative flag (bit 31)
    var flagN: Bool {
        get { cpsr & (1 << 31) != 0 }
        set { if newValue { cpsr |= (1 << 31) } else { cpsr &= ~(1 << 31) } }
    }

    /// Zero flag (bit 30)
    var flagZ: Bool {
        get { cpsr & (1 << 30) != 0 }
        set { if newValue { cpsr |= (1 << 30) } else { cpsr &= ~(1 << 30) } }
    }

    /// Carry flag (bit 29)
    var flagC: Bool {
        get { cpsr & (1 << 29) != 0 }
        set { if newValue { cpsr |= (1 << 29) } else { cpsr &= ~(1 << 29) } }
    }

    /// Overflow flag (bit 28)
    var flagV: Bool {
        get { cpsr & (1 << 28) != 0 }
        set { if newValue { cpsr |= (1 << 28) } else { cpsr &= ~(1 << 28) } }
    }

    /// Sticky saturation flag (bit 27, ARMv5TE only)
    var flagQ: Bool {
        get { cpsr & (1 << 27) != 0 }
        set { if newValue { cpsr |= (1 << 27) } else { cpsr &= ~(1 << 27) } }
    }

    /// Thumb state (bit 5): 0 = ARM mode, 1 = Thumb mode
    var thumbMode: Bool {
        get { cpsr & (1 << 5) != 0 }
        set { if newValue { cpsr |= (1 << 5) } else { cpsr &= ~(1 << 5) } }
    }

    /// IRQ disable (bit 7): 1 = IRQs masked
    var irqDisable: Bool {
        get { cpsr & (1 << 7) != 0 }
        set { if newValue { cpsr |= (1 << 7) } else { cpsr &= ~(1 << 7) } }
    }

    /// FIQ disable (bit 6): 1 = FIQs masked
    var fiqDisable: Bool {
        get { cpsr & (1 << 6) != 0 }
        set { if newValue { cpsr |= (1 << 6) } else { cpsr &= ~(1 << 6) } }
    }

    /// Current processor mode
    var mode: ARMMode {
        ARMMode(rawValue: UInt8(cpsr & 0x1F)) ?? .system
    }

    // MARK: - Mode Switching

    /// Switch processor mode, banking and restoring SP/LR registers.
    /// Does NOT modify CPSR mode bits — caller must do that.
    func switchMode(to newMode: ARMMode) {
        let oldMode = mode
        guard oldMode != newMode else { return }

        // Bank current SP and LR
        bankedSP[oldMode.rawValue] = r[13]
        bankedLR[oldMode.rawValue] = r[14]

        // Handle FIQ banked registers R8-R12
        if oldMode == .fiq {
            for i in 0..<5 { fiqR8_12[i] = r[8 + i] }
            for i in 0..<5 { r[8 + i] = usrR8_12[i] }
        } else if newMode == .fiq {
            for i in 0..<5 { usrR8_12[i] = r[8 + i] }
            for i in 0..<5 { r[8 + i] = fiqR8_12[i] }
        }

        // Restore new mode's SP and LR
        r[13] = bankedSP[newMode.rawValue] ?? 0
        r[14] = bankedLR[newMode.rawValue] ?? 0

        // Update mode bits
        cpsr = (cpsr & ~UInt32(0x1F)) | UInt32(newMode.rawValue)
    }

    // MARK: - Exception Entry

    /// Enter an exception: saves CPSR to SPSR, sets mode, disables IRQ, jumps to vector.
    /// Returns the vector address.
    func enterException(mode newMode: ARMMode, returnOffset: UInt32, vector: UInt32) {
        let oldCPSR = cpsr
        switchMode(to: newMode)
        spsr[newMode.rawValue] = oldCPSR
        r[14] = pc &- returnOffset
        irqDisable = true
        thumbMode = false  // Always enter exceptions in ARM state
        if newMode == .fiq { fiqDisable = true }
        pc = vector
    }

    /// Return from exception: restores CPSR from SPSR
    func returnFromException() {
        let currentMode = mode
        guard let savedPSR = spsr[currentMode.rawValue] else { return }
        let targetMode = ARMMode(rawValue: UInt8(savedPSR & 0x1F)) ?? .system
        switchMode(to: targetMode)
        cpsr = savedPSR
    }

    // MARK: - Condition Evaluation

    /// Evaluate ARM condition code (bits 31:28 of instruction)
    func conditionPassed(_ cond: UInt32) -> Bool {
        switch cond {
        case 0x0: return flagZ                          // EQ
        case 0x1: return !flagZ                         // NE
        case 0x2: return flagC                          // CS/HS
        case 0x3: return !flagC                         // CC/LO
        case 0x4: return flagN                          // MI
        case 0x5: return !flagN                         // PL
        case 0x6: return flagV                          // VS
        case 0x7: return !flagV                         // VC
        case 0x8: return flagC && !flagZ                // HI
        case 0x9: return !flagC || flagZ                // LS
        case 0xA: return flagN == flagV                 // GE
        case 0xB: return flagN != flagV                 // LT
        case 0xC: return !flagZ && (flagN == flagV)     // GT
        case 0xD: return flagZ || (flagN != flagV)      // LE
        case 0xE: return true                           // AL (always)
        case 0xF: return true                           // Unconditional (ARMv5+)
        default:  return true
        }
    }
}
