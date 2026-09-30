import Foundation

/// The 16-channel Sound Processing Unit (SPU).
public final class SPU {
    public let channels: [SoundChannel]
    private unowned let bus: Bus
    
    public var masterControl: UInt32 = 0
    
    init(bus: Bus) {
        self.bus = bus
        self.channels = (0..<16).map { SoundChannel(index: $0, bus: bus) }
    }
    
    public func step(cycles: Int) -> (left: Float, right: Float) {
        var leftMix: Float = 0.0
        var rightMix: Float = 0.0
        
        for channel in channels {
            let (l, r) = channel.step(cycles: cycles)
            leftMix += l
            rightMix += r
        }
        
        return (leftMix, rightMix)
    }
}
