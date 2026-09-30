import Foundation

public final class GPU {
    public let engineA = Engine2D(isEngineA: true)
    public let engineB = Engine2D(isEngineA: false)
    
    private var cycles: Int = 0
    private var vcount: Int = 0
    private unowned let bus: Bus
    
    init(bus: Bus) {
        self.bus = bus
    }
    
    func tick(cycles cyclesAdded: Int, touchscreen: Touchscreen) {
        cycles += cyclesAdded
        
        // DS line is roughly 2128 cycles (at 33MHz ARM7 clock / 67MHz ARM9 clock)
        // Adjust for ARM9 clock ticks (if cycles are ARM9 cycles, a line is ~355 * 6)
        let cyclesPerLine = 2142 * 2 // approximation using ARM9 cycles
        
        while cycles >= cyclesPerLine {
            cycles -= cyclesPerLine
            
            // Advance line
            vcount += 1
            if vcount >= 263 { // 192 active + 71 vblank
                vcount = 0
            }
            
            // Update VCOUNT register (0x04000006)
            bus.io9.write16(0x04000006, value: UInt16(vcount))
            
            if vcount < 192 {
                // Active display
                engineA.renderScanline(y: vcount, bus: bus, touchscreen: touchscreen)
                engineB.renderScanline(y: vcount, bus: bus, touchscreen: touchscreen)
            } else if vcount == 192 {
                // VBlank starts
                // Typically set IF flags in bus for VBlank IRQ
                // Trigger VBlank interrupt on ARM9/ARM7
            }
            
            // Handle HBlank / VCounter interrupts if needed based on DISPSTAT
        }
    }
}
