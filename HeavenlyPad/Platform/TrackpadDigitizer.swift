// HeavenlyPad/Platform/TrackpadDigitizer.swift

import AppKit

/// Simple 1-Euro filter implementation for jitter removal
struct OneEuroFilter {
    private var lastTime: TimeInterval = -1
    private var lastValue: Double = 0
    private var lastDx: Double = 0
    
    var minCutoff: Double = 1.0
    var beta: Double = 0.007
    var dCutoff: Double = 1.0
    
    private func alpha(cutoff: Double, dt: Double) -> Double {
        let tau = 1.0 / (2.0 * .pi * cutoff)
        return 1.0 / (1.0 + tau / dt)
    }
    
    mutating func filter(_ value: Double, timestamp: TimeInterval) -> Double {
        if lastTime < 0 {
            lastTime = timestamp
            lastValue = value
            return value
        }
        
        let dt = timestamp - lastTime
        guard dt > 0 else { return lastValue }
        
        let dx = (value - lastValue) / dt
        let edx = alpha(cutoff: dCutoff, dt: dt) * dx + (1.0 - alpha(cutoff: dCutoff, dt: dt)) * lastDx
        lastDx = edx
        
        let cutoff = minCutoff + beta * abs(edx)
        let a = alpha(cutoff: cutoff, dt: dt)
        let filtered = a * value + (1.0 - a) * lastValue
        
        lastValue = filtered
        lastTime = timestamp
        return filtered
    }
}

final class TrackpadDigitizer {
    private var filterX = OneEuroFilter()
    private var filterY = OneEuroFilter()
    
    var dsWidth: Double = 256.0
    var dsHeight: Double = 192.0
    
    func processEvent(_ event: NSEvent, touchscreen: Touchscreen, view: NSView) {
        let allTouches = event.touches(matching: .any, in: view)
        
        if let touch = allTouches.first(where: { $0.phase == .began || $0.phase == .moved || $0.phase == .stationary }) {
            if touch.phase == .began {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                touchscreen.isPressed = true
                filterX = OneEuroFilter()
                filterY = OneEuroFilter()
                print("TOUCH BEGAN")
            } else if touch.phase == .moved {
                print("TOUCH MOVED")
            }
            
            let rawX = Double(touch.normalizedPosition.x)
            let rawY = Double(touch.normalizedPosition.y)
            
            let rawDsX = rawY
            let rawDsY = rawX
            
            let dsX = Int(rawDsX * 255.0)
            let dsY = Int(rawDsY * 191.0)
            
            touchscreen.screenX = max(0, min(255, dsX))
            touchscreen.screenY = max(0, min(191, dsY))
            print("TOUCH X: \(touchscreen.screenX), Y: \(touchscreen.screenY)")
            
        } else if allTouches.contains(where: { $0.phase == .ended || $0.phase == .cancelled }) {
            print("TOUCH ENDED")
            touchscreen.isPressed = false
        }
    }
}
