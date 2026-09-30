import Foundation

public final class Engine2D {
    public let isEngineA: Bool
    
    // Output framebuffer, 256x192, 32-bit RGBA (or BGRA)
    // We'll use 0xAARRGGBB or similar depending on Metal format. Let's use 0xFF_RR_GG_BB for now.
    public var framebuffer: [UInt32]
    
    public init(isEngineA: Bool) {
        self.isEngineA = isEngineA
        self.framebuffer = Array(repeating: 0xFF000000, count: 256 * 192)
    }
    
    // We use a simple frame counter to animate
    static var frameCounter: Int = 0

    func renderScanline(y: Int, bus: Bus, touchscreen: Touchscreen) {
        let width = 256
        let offset = y * width
        let fc = Engine2D.frameCounter
        
        // Touchscreen cursor bounds (draw a small white square)
        let isCursorLine = touchscreen.isPressed && abs(y - touchscreen.screenY) < 3
        
        for x in 0..<width {
            if isCursorLine && abs(x - touchscreen.screenX) < 3 {
                framebuffer[offset + x] = 0xFFFFFFFF // White dot for touch
                continue
            }
            
            let cx = (x + fc) / 16
            let cy = (y + fc) / 16
            let isChecker = (cx + cy) % 2 == 0
            
            if isEngineA {
                framebuffer[offset + x] = isChecker ? 0xFFFF0000 : 0xFF880000 // Red pattern
            } else {
                framebuffer[offset + x] = isChecker ? 0xFF0000FF : 0xFF000088 // Blue pattern
            }
        }
        
        if y == 191 && !isEngineA {
            Engine2D.frameCounter += 1
        }
    }
}
