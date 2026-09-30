// HeavenlyPad/Core/IO/IPC.swift
// Inter-Processor Communication (Sync and FIFO)

import Foundation

final class IPC {
    // Sync registers
    var sync9: UInt16 = 0
    var sync7: UInt16 = 0
    
    // FIFOs
    struct FIFOQueue {
        var buffer = [UInt32](repeating: 0, count: 16)
        var head = 0, tail = 0, count = 0
        var isEmpty: Bool { count == 0 }
        var isFull: Bool { count >= 16 }
        
        mutating func push(_ value: UInt32) {
            guard !isFull else { return }
            buffer[tail] = value
            tail = (tail + 1) & 0xF
            count += 1
        }
        
        mutating func pop() -> UInt32 {
            guard !isEmpty else { return 0 }
            let value = buffer[head]
            head = (head + 1) & 0xF
            count -= 1
            return value
        }
        
        mutating func clear() {
            head = 0
            tail = 0
            count = 0
        }
    }
    
    var fifo9to7 = FIFOQueue()
    var fifo7to9 = FIFOQueue()
    
    var fifoCnt9: UInt16 = 0x0101
    var fifoCnt7: UInt16 = 0x0101
    
    func writeSync9(_ value: UInt16) {
        sync7 = (sync7 & 0xFFF0) | ((value >> 8) & 0xF)
        sync9 = (sync9 & 0x000F) | (value & 0xFF00)
        
        if value & (1 << 13) != 0 && sync7 & (1 << 14) != 0 {
            // Fire IPC Sync IRQ on ARM7
        }
    }
    
    func writeSync7(_ value: UInt16) {
        sync9 = (sync9 & 0xFFF0) | ((value >> 8) & 0xF)
        sync7 = (sync7 & 0x000F) | (value & 0xFF00)
        
        if value & (1 << 13) != 0 && sync9 & (1 << 14) != 0 {
            // Fire IPC Sync IRQ on ARM9
        }
    }
    
    func updateFIFOFlags() {
        // ARM9 side
        if fifo9to7.isEmpty { fifoCnt9 |= (1 << 0) } else { fifoCnt9 &= ~(1 << 0) }
        if fifo9to7.isFull { fifoCnt9 |= (1 << 1) } else { fifoCnt9 &= ~(1 << 1) }
        if fifo7to9.isEmpty { fifoCnt9 |= (1 << 8) } else { fifoCnt9 &= ~(1 << 8) }
        if fifo7to9.isFull { fifoCnt9 |= (1 << 9) } else { fifoCnt9 &= ~(1 << 9) }
        
        // ARM7 side
        if fifo7to9.isEmpty { fifoCnt7 |= (1 << 0) } else { fifoCnt7 &= ~(1 << 0) }
        if fifo7to9.isFull { fifoCnt7 |= (1 << 1) } else { fifoCnt7 &= ~(1 << 1) }
        if fifo9to7.isEmpty { fifoCnt7 |= (1 << 8) } else { fifoCnt7 &= ~(1 << 8) }
        if fifo9to7.isFull { fifoCnt7 |= (1 << 9) } else { fifoCnt7 &= ~(1 << 9) }
    }
}
