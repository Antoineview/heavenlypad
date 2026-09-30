// HeavenlyPad/Core/IO/Touchscreen.swift

import Foundation

/// Emulates the TSC2046 SPI Touchscreen controller
final class Touchscreen {
    /// Screen coordinates (0-255, 0-191)
    var screenX: Int = 0
    var screenY: Int = 0
    var isPressed: Bool = false
    
    private var command: UInt8 = 0
    private var adcValue: UInt16 = 0
    private var bitCount: Int = 0
    
    /// Transfer a byte via SPI
    func transfer(_ byte: UInt8) -> UInt8 {
        // Simple SPI state machine for TSC2046
        var response: UInt8 = 0
        
        // If a new command starts
        if byte & 0x80 != 0 {
            command = byte
            
            let channel = (command >> 4) & 0x07
            
            // Firmware calibration (approximate conversion to 12-bit ADC)
            // DS touchscreen X ADC: ~200 to ~3800
            // DS touchscreen Y ADC: ~200 to ~3800
            if isPressed {
                switch channel {
                case 1: // Y position
                    adcValue = UInt16(200 + (screenY * 3600) / 192)
                case 5: // X position
                    adcValue = UInt16(200 + (screenX * 3600) / 256)
                case 3, 4: // Z1, Z2 (Pressure)
                    adcValue = 0x0FFF // max pressure
                default:
                    adcValue = 0
                }
            } else {
                adcValue = 0 // No touch
            }
            
            // The first response byte after command is usually 0
            response = 0
            bitCount = 0
        } else {
            // Read 12-bit ADC value across two bytes (shifted by 3 or 4 bits depending on protocol)
            if bitCount == 0 {
                response = UInt8((adcValue >> 5) & 0x7F)
                bitCount += 8
            } else {
                response = UInt8((adcValue << 3) & 0xF8)
                bitCount = 0
            }
        }
        
        return response
    }
}
