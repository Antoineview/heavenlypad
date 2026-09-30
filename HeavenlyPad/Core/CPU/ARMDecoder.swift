// HeavenlyPad/Core/CPU/ARMDecoder.swift
// ARM Instruction Decoder

import Foundation

enum ARMInstructionClass {
    case dataProcessing
    case multiply
    case multiplyLong
    case branchExchange
    case loadStore
    case loadStoreHalfword
    case loadStoreMultiple
    case branch
    case softwareInterrupt
    case coprocessor
    case undefined
}

final class ARMInterpreter {
    let cpu: CPUState
    let bus: Bus
    let isARM9: Bool
    
    private var armTable: [ARMInstructionClass] = []
    
    init(cpu: CPUState, bus: Bus, isARM9: Bool) {
        self.cpu = cpu
        self.bus = bus
        self.isARM9 = isARM9
        buildARMTable()
    }
    
    func step() {
        if cpu.halted { return }
        
        if cpu.thumbMode {
            let pc = cpu.pc & ~1
            let instr = isARM9 ? bus.read16ARM9(pc) : bus.read16ARM7(pc)
            // PC reads as PC+4 in Thumb mode
            cpu.pc = pc &+ 2
            executeThumb(instr)
        } else {
            let pc = cpu.pc & ~3
            let instr = isARM9 ? bus.read32ARM9(pc) : bus.read32ARM7(pc)
            // PC reads as PC+8 in ARM mode
            cpu.pc = pc &+ 4
            
            let cond = instr >> 28
            if cpu.conditionPassed(cond) {
                executeARM(instr)
            }
        }
    }
    
    private func buildARMTable() {
        armTable = [ARMInstructionClass](repeating: .undefined, count: 4096)
        for i in 0..<4096 {
            let op1 = (i >> 4) & 0xFF
            let op2 = i & 0xF
            
            if (op1 & 0xE0) == 0x00 {
                if (op1 & 0x19) == 0x10 && (op2 & 0x9) == 0x9 {
                    armTable[i] = .multiply
                } else if (op1 & 0x19) == 0x10 && (op2 & 0x9) == 0x1 {
                    armTable[i] = .branchExchange
                } else if (op1 & 0x19) == 0x10 && (op2 & 0x9) == 0x1 {
                    armTable[i] = .loadStoreHalfword
                } else if (op1 & 0x1B) == 0x12 && (op2 & 0x9) == 0x1 {
                    armTable[i] = .branchExchange
                } else {
                    armTable[i] = .dataProcessing
                }
            } else if (op1 & 0xE0) == 0x20 {
                armTable[i] = .dataProcessing
            } else if (op1 & 0xC0) == 0x40 {
                armTable[i] = .loadStore
            } else if (op1 & 0xE0) == 0x80 {
                armTable[i] = .loadStoreMultiple
            } else if (op1 & 0xE0) == 0xA0 {
                armTable[i] = .branch
            } else if (op1 & 0xE0) == 0xC0 {
                armTable[i] = .coprocessor
            } else if (op1 & 0xF0) == 0xF0 {
                armTable[i] = .softwareInterrupt
            }
        }
    }
    
    func executeARM(_ instr: UInt32) {
        let hash = Int(((instr >> 16) & 0xFF0) | ((instr >> 4) & 0xF))
        switch armTable[hash] {
        case .dataProcessing: armDataProcessing(instr)
        case .multiply: armMultiply(instr)
        case .multiplyLong: armMultiply(instr)
        case .branchExchange: armBranchExchange(instr)
        case .loadStore: armLoadStore(instr)
        case .loadStoreHalfword: armLoadStoreHalfword(instr)
        case .loadStoreMultiple: armLoadStoreMultiple(instr)
        case .branch: armBranch(instr)
        case .softwareInterrupt: armSoftwareInterrupt(instr)
        case .coprocessor: armCoprocessor(instr)
        case .undefined: armUndefined(instr)
        }
    }
    
    func armUndefined(_ instr: UInt32) {
        cpu.enterException(mode: .undefined, returnOffset: 4, vector: 0x00000004)
    }
    
    func armCoprocessor(_ instr: UInt32) {
        // Stub for CP15
    }
}
