import Foundation

/// A single SPU audio channel supporting PCM8, PCM16, ADPCM, PSG, and Noise.
public final class SoundChannel {
    public let index: Int
    private unowned let bus: Bus
    
    public var control: UInt32 = 0
    public var sourceAddress: UInt32 = 0
    public var timer: UInt16 = 0
    public var loopStart: UInt32 = 0
    public var length: UInt32 = 0
    
    public var currentAddress: UInt32 = 0
    public var isPlaying: Bool = false
    private var timerCounter: Int = 0
    
    public var format: Int { Int((control >> 29) & 3) }
    public var repeatMode: Int { Int((control >> 27) & 3) }
    public var volume: Int { Int(control & 0x7F) }
    public var pan: Int { Int((control >> 16) & 0x7F) }
    
    init(index: Int, bus: Bus) {
        self.index = index
        self.bus = bus
    }
    
    public func writeControl(_ value: UInt32) {
        let oldPlaying = isPlaying
        control = value
        isPlaying = (control & (1 << 31)) != 0
        
        if !oldPlaying && isPlaying {
            currentAddress = sourceAddress
            timerCounter = 0
        }
    }
    
    public func step(cycles: Int) -> (left: Float, right: Float) {
        guard isPlaying else { return (0, 0) }
        
        // Basic cycle accurate step logic (simplified for stub)
        timerCounter += cycles
        
        // Calculate period: freq = 16756991 / (65536 - timer)
        let period = 16756991 / max(1, Int(65536 - Int(timer)))
        
        if timerCounter >= period {
            timerCounter -= period
            // Advance sample
            if format == 0 { // PCM8
                _ = bus.read8ARM7(currentAddress)
                currentAddress &+= 1
            } else if format == 1 { // PCM16
                _ = bus.read16ARM7(currentAddress)
                currentAddress &+= 2
            }
        }
        
        return (0.0, 0.0) // Return silence for now
    }
}
