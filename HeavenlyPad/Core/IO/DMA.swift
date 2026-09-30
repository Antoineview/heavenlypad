// HeavenlyPad/Core/IO/DMA.swift
// Direct Memory Access Controllers for ARM9 and ARM7

import Foundation

final class DMAController {
    let cpuIndex: Int // 9 or 7
    unowned let bus: Bus
    unowned let cpu: CPUState
    
    struct Channel {
        var source: UInt32 = 0
        var dest: UInt32 = 0
        var count: UInt32 = 0
        var control: UInt16 = 0
        
        // Active registers
        var currentSource: UInt32 = 0
        var currentDest: UInt32 = 0
        var currentCount: UInt32 = 0
        
        var isEnabled: Bool { control & (1 << 15) != 0 }
        var isRepeated: Bool { control & (1 << 9) != 0 }
        var is32Bit: Bool { control & (1 << 10) != 0 }
        var startTiming: UInt16 { (control >> 11) & 0x7 }
        
        var destControl: UInt16 { (control >> 5) & 0x3 }
        var sourceControl: UInt16 { (control >> 7) & 0x3 }
    }
    
    var channels = [Channel(), Channel(), Channel(), Channel()]
    
    init(cpuIndex: Int, bus: Bus, cpu: CPUState) {
        self.cpuIndex = cpuIndex
        self.bus = bus
        self.cpu = cpu
    }
    
    func writeSource(_ ch: Int, _ value: UInt32) {
        channels[ch].source = value & 0x0FFFFFFF
    }
    
    func writeDest(_ ch: Int, _ value: UInt32) {
        channels[ch].dest = value & 0x0FFFFFFF
    }
    
    func writeCount(_ ch: Int, _ value: UInt16) {
        channels[ch].count = UInt32(value)
    }
    
    func writeControl(_ ch: Int, _ value: UInt16) {
        let wasEnabled = channels[ch].isEnabled
        channels[ch].control = value
        
        if !wasEnabled && channels[ch].isEnabled {
            // Triggered! Reload active registers
            channels[ch].currentSource = channels[ch].source
            channels[ch].currentDest = channels[ch].dest
            channels[ch].currentCount = channels[ch].count
            
            // Immediate start?
            if channels[ch].startTiming == 0 {
                execute(ch)
            }
        }
    }
    
    func triggerVBlank() {
        for i in 0..<4 where channels[i].isEnabled && channels[i].startTiming == 1 {
            execute(i)
        }
    }
    
    func checkTriggers() {
        // Evaluate other start timings (HBlank, etc.)
        // This is typically called from the main emulator loop
    }
    
    private func execute(_ ch: Int) {
        let is32 = channels[ch].is32Bit
        let wordSize: UInt32 = is32 ? 4 : 2
        var count = channels[ch].currentCount
        if count == 0 { count = cpuIndex == 9 ? 0x200000 : 0x10000 }
        
        for _ in 0..<count {
            if is32 {
                let data = cpuIndex == 9 ? bus.read32ARM9(channels[ch].currentSource) : bus.read32ARM7(channels[ch].currentSource)
                if cpuIndex == 9 { bus.write32ARM9(channels[ch].currentDest, value: data) }
                else { bus.write32ARM7(channels[ch].currentDest, value: data) }
            } else {
                let data = cpuIndex == 9 ? bus.read16ARM9(channels[ch].currentSource) : bus.read16ARM7(channels[ch].currentSource)
                if cpuIndex == 9 { bus.write16ARM9(channels[ch].currentDest, value: data) }
                else { bus.write16ARM7(channels[ch].currentDest, value: data) }
            }
            
            // Address updates
            updateAddress(&channels[ch].currentSource, mode: channels[ch].sourceControl, wordSize: wordSize)
            updateAddress(&channels[ch].currentDest, mode: channels[ch].destControl, wordSize: wordSize)
        }
        
        // Completion
        if channels[ch].isRepeated {
            // Reload count, leave source/dest as-is (except if reload mode)
            if channels[ch].destControl == 3 {
                channels[ch].currentDest = channels[ch].dest
            }
            channels[ch].currentCount = channels[ch].count
        } else {
            channels[ch].control &= ~(1 << 15) // Disable
        }
        
        // Check IRQ
        if channels[ch].control & (1 << 14) != 0 {
            // Fire DMA IRQ
            // cpu.requestIRQ(...)
        }
    }
    
    private func updateAddress(_ address: inout UInt32, mode: UInt16, wordSize: UInt32) {
        switch mode {
        case 0: address &+= wordSize // Increment
        case 1: address &-= wordSize // Decrement
        case 2: break                // Fixed
        case 3: address &+= wordSize // Increment/Reload
        default: break
        }
    }
}
