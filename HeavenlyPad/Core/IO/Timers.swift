// HeavenlyPad/Core/IO/Timers.swift
// 16-bit hardware timers

import Foundation

final class TimerController {
    struct Timer {
        var counter: UInt32 = 0
        var reload: UInt16 = 0
        var control: UInt16 = 0
        
        var isRunning: Bool { control & (1 << 7) != 0 }
        var cascade: Bool { control & (1 << 2) != 0 }
        var irqEnabled: Bool { control & (1 << 6) != 0 }
        
        var prescaler: Int {
            switch control & 0x3 {
            case 0: return 1       // F/1
            case 1: return 64      // F/64
            case 2: return 256     // F/256
            case 3: return 1024    // F/1024
            default: return 1
            }
        }
    }
    
    var timers = [Timer(), Timer(), Timer(), Timer()]
    var onOverflow: ((Int) -> Void)?
    
    func tick(cycles: Int) {
        for i in 0..<4 {
            guard timers[i].isRunning && !timers[i].cascade else { continue }
            
            let ticks = cycles / timers[i].prescaler
            timers[i].counter += UInt32(ticks)
            
            while timers[i].counter >= 0x10000 {
                timers[i].counter = UInt32(timers[i].reload) + (timers[i].counter - 0x10000)
                
                if timers[i].irqEnabled {
                    onOverflow?(i)
                }
                
                // Cascade
                if i < 3 && timers[i+1].cascade && timers[i+1].isRunning {
                    timers[i+1].counter += 1
                }
            }
        }
    }
}
