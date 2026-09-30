// HeavenlyPad/Core/CPU/ARMInstructions.swift
// ARM Instruction Implementations

import Foundation

extension ARMInterpreter {
    func armDataProcessing(_ instr: UInt32) {
        // Basic stub for Data Processing
        let opcode = (instr >> 21) & 0xF
        let s = (instr & (1 << 20)) != 0
        let rd = Int((instr >> 12) & 0xF)
        
        // This is a minimal implementation placeholder for the full ALU
        // Real implementation would decode shifter_operand and set flags
        var result: UInt32 = 0
        if opcode == 0xD { // MOV
            result = instr & 0xFF // simplified imm
        }
        
        if rd == 15 {
            if s { cpu.returnFromException() }
            cpu.pc = result
        } else {
            cpu.r[rd] = result
        }
    }
    
    func armMultiply(_ instr: UInt32) {
        let rd = Int((instr >> 16) & 0xF)
        let rn = Int((instr >> 12) & 0xF)
        let rs = Int((instr >> 8) & 0xF)
        let rm = Int(instr & 0xF)
        let accumulate = (instr & (1 << 21)) != 0
        let setFlags = (instr & (1 << 20)) != 0
        
        let valM = cpu.r[rm]
        let valS = cpu.r[rs]
        var res = valM &* valS
        
        if accumulate {
            res = res &+ cpu.r[rn]
        }
        
        cpu.r[rd] = res
        
        if setFlags {
            cpu.flagN = (res & 0x80000000) != 0
            cpu.flagZ = (res == 0)
        }
    }
    
    func armBranchExchange(_ instr: UInt32) {
        let rn = Int(instr & 0xF)
        let addr = cpu.r[rn]
        let isLink = (instr & (1 << 5)) != 0 // BLX has bit 5 set
        
        if isLink {
            cpu.lr = cpu.pc &- 4
        }
        
        if addr & 1 != 0 {
            cpu.thumbMode = true
            cpu.pc = addr & ~1
        } else {
            cpu.thumbMode = false
            cpu.pc = addr & ~3
        }
    }
    
    func armLoadStore(_ instr: UInt32) {
        let rd = Int((instr >> 12) & 0xF)
        // Simplified load/store stub
        if (instr & (1 << 20)) != 0 {
            // LDR
            cpu.r[rd] = 0
        } else {
            // STR
            _ = cpu.r[rd]
        }
    }
    
    func armLoadStoreHalfword(_ instr: UInt32) {
        // Stub
    }
    
    func armLoadStoreMultiple(_ instr: UInt32) {
        // Stub
    }
    
    func armBranch(_ instr: UInt32) {
        let l = (instr & (1 << 24)) != 0
        var offset = instr & 0x00FFFFFF
        if (offset & 0x00800000) != 0 {
            offset |= 0xFF000000
        }
        
        // PC is already instruction + 4, need to add 4 to reach instruction + 8
        let target = (cpu.pc &+ 4) &+ (offset << 2)
        
        if l {
            cpu.lr = cpu.pc &- 4
        }
        cpu.pc = target
    }
    
    func armSoftwareInterrupt(_ instr: UInt32) {
        cpu.enterException(mode: .supervisor, returnOffset: 4, vector: 0x00000008)
    }
}
