// HeavenlyPad/Core/Memory/Bus.swift
// Main memory bus and address decoder

import Foundation

final class Bus {
    // MARK: - Memory Regions
    let mainRAM: UnsafeMutableRawPointer
    let sharedWRAM: UnsafeMutableRawPointer
    let arm7WRAM: UnsafeMutableRawPointer
    let paletteRAM: UnsafeMutableRawPointer
    let oam: UnsafeMutableRawPointer
    let itcm: UnsafeMutableRawPointer
    let dtcm: UnsafeMutableRawPointer
    
    // MARK: - Subsystems
    var io9 = IORegisters9()
    var io7 = IORegisters7()
    var vram = VRAMController()
    var cartridge = CartridgeInterface()
    var cp15 = CP15()
    
    init() {
        // Allocate raw memory blocks (aligned to 16 bytes)
        mainRAM = .allocate(byteCount: 4 * 1024 * 1024, alignment: 16)
        sharedWRAM = .allocate(byteCount: 32 * 1024, alignment: 16)
        arm7WRAM = .allocate(byteCount: 64 * 1024, alignment: 16)
        paletteRAM = .allocate(byteCount: 2 * 1024, alignment: 16)
        oam = .allocate(byteCount: 2 * 1024, alignment: 16)
        itcm = .allocate(byteCount: 32 * 1024, alignment: 16)
        dtcm = .allocate(byteCount: 16 * 1024, alignment: 16)
        
        // Zero initialize
        mainRAM.initializeMemory(as: UInt8.self, repeating: 0, count: 4 * 1024 * 1024)
        sharedWRAM.initializeMemory(as: UInt8.self, repeating: 0, count: 32 * 1024)
        arm7WRAM.initializeMemory(as: UInt8.self, repeating: 0, count: 64 * 1024)
        paletteRAM.initializeMemory(as: UInt8.self, repeating: 0, count: 2 * 1024)
        oam.initializeMemory(as: UInt8.self, repeating: 0, count: 2 * 1024)
        itcm.initializeMemory(as: UInt8.self, repeating: 0, count: 32 * 1024)
        dtcm.initializeMemory(as: UInt8.self, repeating: 0, count: 16 * 1024)
    }
    
    deinit {
        mainRAM.deallocate()
        sharedWRAM.deallocate()
        arm7WRAM.deallocate()
        paletteRAM.deallocate()
        oam.deallocate()
        itcm.deallocate()
        dtcm.deallocate()
    }
    
    // MARK: - ARM9 Reads
    
    func read8ARM9(_ address: UInt32) -> UInt8 {
        if address < cp15.itcmSize { return itcm.load(fromByteOffset: Int(address), as: UInt8.self) }
        if cp15.dtcmEnabled && address >= cp15.dtcmBase && address < cp15.dtcmEnd {
            return dtcm.load(fromByteOffset: Int(address - cp15.dtcmBase), as: UInt8.self)
        }
        
        let addr = address & 0x0FFF_FFFF
        switch addr >> 24 {
        case 0x02: return mainRAM.load(fromByteOffset: Int(addr & 0x3F_FFFF), as: UInt8.self)
        case 0x03: return sharedWRAM.load(fromByteOffset: Int(addr & 0x7FFF), as: UInt8.self)
        case 0x04: return io9.read8(addr)
        case 0x05: return paletteRAM.load(fromByteOffset: Int(addr & 0x7FF), as: UInt8.self)
        case 0x06: return vram.read8ARM9(addr)
        case 0x07: return oam.load(fromByteOffset: Int(addr & 0x7FF), as: UInt8.self)
        default: return 0
        }
    }
    
    func read16ARM9(_ address: UInt32) -> UInt16 {
        let aligned = address & ~1
        if aligned < cp15.itcmSize { return itcm.load(fromByteOffset: Int(aligned), as: UInt16.self) }
        if cp15.dtcmEnabled && aligned >= cp15.dtcmBase && aligned < cp15.dtcmEnd {
            return dtcm.load(fromByteOffset: Int(aligned - cp15.dtcmBase), as: UInt16.self)
        }
        
        let addr = aligned & 0x0FFF_FFFF
        switch addr >> 24 {
        case 0x02: return mainRAM.load(fromByteOffset: Int(addr & 0x3F_FFFF), as: UInt16.self)
        case 0x03: return sharedWRAM.load(fromByteOffset: Int(addr & 0x7FFF), as: UInt16.self)
        case 0x04: return io9.read16(addr)
        case 0x05: return paletteRAM.load(fromByteOffset: Int(addr & 0x7FF), as: UInt16.self)
        case 0x06: return vram.read16ARM9(addr)
        case 0x07: return oam.load(fromByteOffset: Int(addr & 0x7FF), as: UInt16.self)
        default: return 0
        }
    }
    
    func read32ARM9(_ address: UInt32) -> UInt32 {
        let aligned = address & ~3
        if aligned < cp15.itcmSize { return itcm.load(fromByteOffset: Int(aligned), as: UInt32.self) }
        if cp15.dtcmEnabled && aligned >= cp15.dtcmBase && aligned < cp15.dtcmEnd {
            return dtcm.load(fromByteOffset: Int(aligned - cp15.dtcmBase), as: UInt32.self)
        }
        
        let addr = aligned & 0x0FFF_FFFF
        switch addr >> 24 {
        case 0x02: return mainRAM.load(fromByteOffset: Int(addr & 0x3F_FFFF), as: UInt32.self)
        case 0x03: return sharedWRAM.load(fromByteOffset: Int(addr & 0x7FFF), as: UInt32.self)
        case 0x04: return io9.read32(addr)
        case 0x05: return paletteRAM.load(fromByteOffset: Int(addr & 0x7FF), as: UInt32.self)
        case 0x06: return vram.read32ARM9(addr)
        case 0x07: return oam.load(fromByteOffset: Int(addr & 0x7FF), as: UInt32.self)
        default:
            if (address >> 24) == 0xFF { return 0xE3A00000 } // Stub ARM9 BIOS with MOV R0, #0
            return 0
        }
    }
    
    // MARK: - ARM9 Writes
    
    func write8ARM9(_ address: UInt32, value: UInt8) {
        if address < cp15.itcmSize { return itcm.storeBytes(of: value, toByteOffset: Int(address), as: UInt8.self) }
        if cp15.dtcmEnabled && address >= cp15.dtcmBase && address < cp15.dtcmEnd {
            return dtcm.storeBytes(of: value, toByteOffset: Int(address - cp15.dtcmBase), as: UInt8.self)
        }
        
        let addr = address & 0x0FFF_FFFF
        switch addr >> 24 {
        case 0x02: mainRAM.storeBytes(of: value, toByteOffset: Int(addr & 0x3F_FFFF), as: UInt8.self)
        case 0x03: sharedWRAM.storeBytes(of: value, toByteOffset: Int(addr & 0x7FFF), as: UInt8.self)
        case 0x04: io9.write8(addr, value: value)
        case 0x05: paletteRAM.storeBytes(of: value, toByteOffset: Int(addr & 0x7FF), as: UInt8.self)
        case 0x06: vram.write8ARM9(addr, value: value)
        case 0x07: oam.storeBytes(of: value, toByteOffset: Int(addr & 0x7FF), as: UInt8.self)
        default: break
        }
    }
    
    func write16ARM9(_ address: UInt32, value: UInt16) {
        let aligned = address & ~1
        if aligned < cp15.itcmSize { return itcm.storeBytes(of: value, toByteOffset: Int(aligned), as: UInt16.self) }
        if cp15.dtcmEnabled && aligned >= cp15.dtcmBase && aligned < cp15.dtcmEnd {
            return dtcm.storeBytes(of: value, toByteOffset: Int(aligned - cp15.dtcmBase), as: UInt16.self)
        }
        
        let addr = aligned & 0x0FFF_FFFF
        switch addr >> 24 {
        case 0x02: mainRAM.storeBytes(of: value, toByteOffset: Int(addr & 0x3F_FFFF), as: UInt16.self)
        case 0x03: sharedWRAM.storeBytes(of: value, toByteOffset: Int(addr & 0x7FFF), as: UInt16.self)
        case 0x04: io9.write16(addr, value: value)
        case 0x05: paletteRAM.storeBytes(of: value, toByteOffset: Int(addr & 0x7FF), as: UInt16.self)
        case 0x06: vram.write16ARM9(addr, value: value)
        case 0x07: oam.storeBytes(of: value, toByteOffset: Int(addr & 0x7FF), as: UInt16.self)
        default: break
        }
    }
    
    func write32ARM9(_ address: UInt32, value: UInt32) {
        let aligned = address & ~3
        if aligned < cp15.itcmSize { return itcm.storeBytes(of: value, toByteOffset: Int(aligned), as: UInt32.self) }
        if cp15.dtcmEnabled && aligned >= cp15.dtcmBase && aligned < cp15.dtcmEnd {
            return dtcm.storeBytes(of: value, toByteOffset: Int(aligned - cp15.dtcmBase), as: UInt32.self)
        }
        
        let addr = aligned & 0x0FFF_FFFF
        switch addr >> 24 {
        case 0x02: mainRAM.storeBytes(of: value, toByteOffset: Int(addr & 0x3F_FFFF), as: UInt32.self)
        case 0x03: sharedWRAM.storeBytes(of: value, toByteOffset: Int(addr & 0x7FFF), as: UInt32.self)
        case 0x04: io9.write32(addr, value: value)
        case 0x05: paletteRAM.storeBytes(of: value, toByteOffset: Int(addr & 0x7FF), as: UInt32.self)
        case 0x06: vram.write32ARM9(addr, value: value)
        case 0x07: oam.storeBytes(of: value, toByteOffset: Int(addr & 0x7FF), as: UInt32.self)
        default: break
        }
    }
    
    // MARK: - ARM7 Reads
    
    func read8ARM7(_ address: UInt32) -> UInt8 {
        let addr = address & 0x0FFF_FFFF
        switch addr >> 24 {
        case 0x02: return mainRAM.load(fromByteOffset: Int(addr & 0x3F_FFFF), as: UInt8.self)
        case 0x03:
            if addr >= 0x0380_0000 { return arm7WRAM.load(fromByteOffset: Int(addr & 0xFFFF), as: UInt8.self) }
            return sharedWRAM.load(fromByteOffset: Int(addr & 0x7FFF), as: UInt8.self)
        case 0x04: return io7.read8(addr)
        case 0x06: return vram.read8ARM7(addr)
        default: return 0
        }
    }
    
    func read16ARM7(_ address: UInt32) -> UInt16 {
        let addr = (address & 0x0FFF_FFFF) & ~1
        switch addr >> 24 {
        case 0x02: return mainRAM.load(fromByteOffset: Int(addr & 0x3F_FFFF), as: UInt16.self)
        case 0x03:
            if addr >= 0x0380_0000 { return arm7WRAM.load(fromByteOffset: Int(addr & 0xFFFF), as: UInt16.self) }
            return sharedWRAM.load(fromByteOffset: Int(addr & 0x7FFF), as: UInt16.self)
        case 0x04: return io7.read16(addr)
        case 0x06: return vram.read16ARM7(addr)
        default: return 0
        }
    }
    
    func read32ARM7(_ address: UInt32) -> UInt32 {
        let addr = (address & 0x0FFF_FFFF) & ~3
        switch addr >> 24 {
        case 0x02: return mainRAM.load(fromByteOffset: Int(addr & 0x3F_FFFF), as: UInt32.self)
        case 0x03:
            if addr >= 0x0380_0000 { return arm7WRAM.load(fromByteOffset: Int(addr & 0xFFFF), as: UInt32.self) }
            return sharedWRAM.load(fromByteOffset: Int(addr & 0x7FFF), as: UInt32.self)
        case 0x04:
            if addr == 0x0410_0010 { return cartridge.readCardData() }
            return io7.read32(addr)
        case 0x06: return vram.read32ARM7(addr)
        default:
            if (address >> 24) == 0x00 { return 0xE3A00000 } // Stub ARM7 BIOS
            return 0
        }
    }
    
    // MARK: - ARM7 Writes
    
    func write8ARM7(_ address: UInt32, value: UInt8) {
        let addr = address & 0x0FFF_FFFF
        switch addr >> 24 {
        case 0x02: mainRAM.storeBytes(of: value, toByteOffset: Int(addr & 0x3F_FFFF), as: UInt8.self)
        case 0x03:
            if addr >= 0x0380_0000 { arm7WRAM.storeBytes(of: value, toByteOffset: Int(addr & 0xFFFF), as: UInt8.self) }
            else { sharedWRAM.storeBytes(of: value, toByteOffset: Int(addr & 0x7FFF), as: UInt8.self) }
        case 0x04: io7.write8(addr, value: value)
        case 0x06: vram.write8ARM7(addr, value: value)
        default: break
        }
    }
    
    func write16ARM7(_ address: UInt32, value: UInt16) {
        let addr = (address & 0x0FFF_FFFF) & ~1
        switch addr >> 24 {
        case 0x02: mainRAM.storeBytes(of: value, toByteOffset: Int(addr & 0x3F_FFFF), as: UInt16.self)
        case 0x03:
            if addr >= 0x0380_0000 { arm7WRAM.storeBytes(of: value, toByteOffset: Int(addr & 0xFFFF), as: UInt16.self) }
            else { sharedWRAM.storeBytes(of: value, toByteOffset: Int(addr & 0x7FFF), as: UInt16.self) }
        case 0x04: io7.write16(addr, value: value)
        case 0x06: vram.write16ARM7(addr, value: value)
        default: break
        }
    }
    
    func write32ARM7(_ address: UInt32, value: UInt32) {
        let addr = (address & 0x0FFF_FFFF) & ~3
        switch addr >> 24 {
        case 0x02: mainRAM.storeBytes(of: value, toByteOffset: Int(addr & 0x3F_FFFF), as: UInt32.self)
        case 0x03:
            if addr >= 0x0380_0000 { arm7WRAM.storeBytes(of: value, toByteOffset: Int(addr & 0xFFFF), as: UInt32.self) }
            else { sharedWRAM.storeBytes(of: value, toByteOffset: Int(addr & 0x7FFF), as: UInt32.self) }
        case 0x04: io7.write32(addr, value: value)
        case 0x06: vram.write32ARM7(addr, value: value)
        default: break
        }
    }
}
