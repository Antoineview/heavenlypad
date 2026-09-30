// HeavenlyPad/Core/CPU/ThumbInstructions.swift
// Thumb Instruction Decoder and Implementations

import Foundation

extension ARMInterpreter {
    func executeThumb(_ instr: UInt16) {
        let opcode = instr >> 11
        switch opcode {
        case 0x0...0x2: thumbMoveShifted(instr)
        case 0x3: thumbAddSub(instr)
        case 0x4...0x5: thumbDataProcessImm(instr)
        case 0x6...0x7: thumbDataProcessImm(instr)
        case 0x8: thumbDataProcessReg(instr)
        case 0x9: thumbLoadStorePool(instr)
        case 0xA...0xB: thumbLoadStoreReg(instr)
        case 0xC...0xF: thumbLoadStoreWordByte(instr)
        case 0x10...0x11: thumbLoadStoreHalfword(instr)
        case 0x12...0x13: thumbSPRelLoadStore(instr)
        case 0x14...0x15: thumbLoadAddress(instr)
        case 0x16...0x17: thumbSPAddSub(instr)
        case 0x18...0x19: thumbPushPop(instr)
        case 0x1A...0x1B: thumbMultipleLoadStore(instr)
        case 0x1C...0x1D: thumbCondBranch(instr)
        case 0x1E: thumbUncondBranch(instr)
        case 0x1F: thumbLongBranch(instr)
        default: thumbUndefined(instr)
        }
    }
    
    func thumbMoveShifted(_ instr: UInt16) {}
    func thumbAddSub(_ instr: UInt16) {}
    func thumbDataProcessImm(_ instr: UInt16) {}
    func thumbDataProcessReg(_ instr: UInt16) {}
    func thumbLoadStorePool(_ instr: UInt16) {}
    func thumbLoadStoreReg(_ instr: UInt16) {}
    func thumbLoadStoreWordByte(_ instr: UInt16) {}
    func thumbLoadStoreHalfword(_ instr: UInt16) {}
    func thumbSPRelLoadStore(_ instr: UInt16) {}
    func thumbLoadAddress(_ instr: UInt16) {}
    func thumbSPAddSub(_ instr: UInt16) {}
    func thumbPushPop(_ instr: UInt16) {}
    func thumbMultipleLoadStore(_ instr: UInt16) {}
    
    func thumbCondBranch(_ instr: UInt16) {
        let cond = UInt32((instr >> 8) & 0xF)
        if cond == 0xF {
            thumbSoftwareInterrupt(instr)
            return
        }
        
        if cpu.conditionPassed(cond) {
            var offset = Int32(instr & 0xFF)
            if (offset & 0x80) != 0 {
                offset |= -256
            }
            // PC is already +2 here, add another +2 for PC+4 offset
            cpu.pc = cpu.pc &+ 2 &+ UInt32(bitPattern: offset << 1)
        }
    }
    
    func thumbUncondBranch(_ instr: UInt16) {
        var offset = Int32(instr & 0x7FF)
        if (offset & 0x400) != 0 {
            offset |= -2048
        }
        cpu.pc = cpu.pc &+ 2 &+ UInt32(bitPattern: offset << 1)
    }
    
    func thumbLongBranch(_ instr: UInt16) {
        let h = (instr >> 11) & 0x3
        var offset = UInt32(instr & 0x7FF)
        
        if h == 2 {
            // First prefix
            if (offset & 0x400) != 0 { offset |= 0xFFFFF800 }
            cpu.lr = cpu.pc &+ 2 &+ (offset << 12)
        } else if h == 3 {
            // Second prefix
            let target = cpu.lr &+ (offset << 1)
            cpu.lr = (cpu.pc &- 2) | 1
            cpu.pc = target
        }
    }
    
    func thumbSoftwareInterrupt(_ instr: UInt16) {
        cpu.enterException(mode: .supervisor, returnOffset: 2, vector: 0x00000008)
    }
    
    func thumbUndefined(_ instr: UInt16) {
        cpu.enterException(mode: .undefined, returnOffset: 2, vector: 0x00000004)
    }
}
