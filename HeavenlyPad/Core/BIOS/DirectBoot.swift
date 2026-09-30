// HeavenlyPad/Core/BIOS/DirectBoot.swift
// Direct-boot ROM initialization (bypassing firmware)

import Foundation

/// Set up system state for direct-boot ROM loading
func directBoot(bus: Bus, loader: NDSLoader, arm9: CPUState, arm7: CPUState) {
    // 1. Load ARM9 binary into Main RAM
    loader.loadARM9Into(memory: bus.mainRAM, baseAddress: 0x02000000)
    
    // 2. Load ARM7 binary into Main RAM
    loader.loadARM7Into(memory: bus.mainRAM, baseAddress: 0x02000000)
    
    // 3. Initialize ARM9 CPU state
    arm9.pc = loader.header.arm9EntryAddress
    arm9.sp = 0x0380_FD80
    arm9.cpsr = 0x0000_001F // System mode, ARM state
    arm9.bankedSP[ARMMode.irq.rawValue] = 0x0380_FF80
    arm9.bankedSP[ARMMode.supervisor.rawValue] = 0x0380_FFC0
    
    // 4. Initialize ARM7 CPU state
    arm7.pc = loader.header.arm7EntryAddress
    arm7.sp = 0x0380_FD80
    arm7.cpsr = 0x0000_001F // System mode, ARM state
    arm7.bankedSP[ARMMode.irq.rawValue] = 0x0380_FF80
    arm7.bankedSP[ARMMode.supervisor.rawValue] = 0x0380_FFC0
    
    // 5. Initialize CP15 (ARM9)
    bus.cp15.control = 0x0005_2078  // High vectors, ITCM on, DTCM on, caches off
    bus.cp15.dtcmBase = 0x027E_0000
    
    // 6. Populate boot info block at 0x027FF800
    // Copy ROM header (512 bytes)
    for i in 0..<0x200 {
        bus.write8ARM9(0x027F_F800 + UInt32(i), value: loader.romData[i])
    }
    
    // 7. Set boot flags
    bus.write16ARM9(0x027F_F850, value: 0x0001)  // ARM9 boot flag
    bus.write16ARM9(0x027F_F880, value: 0x0001)  // ARM7 boot flag
    
    // 8. Populate user settings at 0x027FFC80
    // Touch calibration data
    let calibBlock: [UInt8] = [
        0x20, 0x00,   // pixel_x1 = 32
        0x20, 0x00,   // pixel_y1 = 32
        0x90, 0x01,   // adc_x1 = 400
        0x90, 0x01,   // adc_y1 = 400
        0xE0, 0x00,   // pixel_x2 = 224
        0xA0, 0x00,   // pixel_y2 = 160
        0x74, 0x0E,   // adc_x2 = 3700
        0xAC, 0x0D,   // adc_y2 = 3500
    ]
    for (i, byte) in calibBlock.enumerated() {
        bus.write8ARM9(0x027F_FC80 + UInt32(i), value: byte)
    }
    
    // 9. Set WRAMCNT (shared WRAM to ARM7)
    // bus.io9.WRAMCNT = 3 // Handled inside IORegisters9 if fully implemented
    
    // 10. Set POWCNT1 (Engine A on top screen, Engine B on bottom)
    // bus.io9.POWCNT1 = 0x820F
}
