// HeavenlyPad/Core/CPU/CP15.swift
// ARM9 System Control Coprocessor (CP15)
// Manages TCM configuration, cache control, and exception vector location

import Foundation

/// ARM9 CP15 System Control Coprocessor
/// Accessed via MRC/MCR instructions: mcr p15, opcode1, Rd, CRn, CRm, opcode2
final class CP15 {

    // MARK: - Control Register (c1)

    /// System control register
    /// Bit 0: Protection Unit enable
    /// Bit 2: Data Cache enable
    /// Bit 7: Big-endian (always 0 on DS)
    /// Bit 12: Instruction Cache enable
    /// Bit 13: High vectors (0=0x00000000, 1=0xFFFF0000)
    /// Bit 14: Round-robin cache replacement
    /// Bit 16: DTCM enable
    /// Bit 18: ITCM enable
    var control: UInt32 = 0x0005_2078

    // MARK: - TCM Configuration

    /// DTCM base address (default 0x027E0000 for DS)
    var dtcmBase: UInt32 = 0x027E_0000

    /// DTCM size in bytes (always 16 KB on ARM946E-S)
    var dtcmSize: UInt32 = 16 * 1024

    /// ITCM size in bytes (always 32 KB on ARM946E-S)
    /// ITCM is always based at 0x00000000
    var itcmSize: UInt32 = 32 * 1024

    // MARK: - Derived Properties

    /// Whether high vectors are enabled (exception vectors at 0xFFFF0000)
    var highVectors: Bool {
        control & (1 << 13) != 0
    }

    /// Exception vector base address
    var vectorBase: UInt32 {
        highVectors ? 0xFFFF_0000 : 0x0000_0000
    }

    /// Whether ITCM is enabled
    var itcmEnabled: Bool {
        control & (1 << 18) != 0
    }

    /// Whether DTCM is enabled
    var dtcmEnabled: Bool {
        control & (1 << 16) != 0
    }

    /// DTCM end address (exclusive)
    var dtcmEnd: UInt32 {
        dtcmBase &+ dtcmSize
    }

    // MARK: - MRC (Read from CP15)

    /// Handle MRC p15, opcode1, Rd, CRn, CRm, opcode2
    func read(crn: Int, crm: Int, opcode2: Int) -> UInt32 {
        switch (crn, crm, opcode2) {
        // c0: ID registers
        case (0, 0, 0): return 0x4105_9461  // Main ID: ARM946E-S r1p1
        case (0, 0, 1): return 0x0F0D_2112  // Cache Type
        case (0, 0, 2): return 0x0014_0180  // TCM Size (DTCM=16KB, ITCM=32KB)

        // c1: Control register
        case (1, 0, 0): return control

        // c2: Cachability
        case (2, 0, 0): return 0  // Data cachable
        case (2, 0, 1): return 0  // Instruction cachable

        // c3: Buffer
        case (3, 0, 0): return 0  // Write bufferable

        // c5: Access permissions
        case (5, 0, 0): return 0  // Data access permissions
        case (5, 0, 1): return 0  // Instruction access permissions
        case (5, 0, 2): return 0  // Extended data access
        case (5, 0, 3): return 0  // Extended instruction access

        // c6: Protection Unit regions
        case (6, _, 0): return 0  // Data protection region
        case (6, _, 1): return 0  // Instruction protection region

        // c9: TCM configuration
        case (9, 1, 0): return encodeTCMConfig(base: dtcmBase, size: dtcmSize)
        case (9, 1, 1): return encodeTCMConfig(base: 0, size: itcmSize)

        default:
            return 0
        }
    }

    // MARK: - MCR (Write to CP15)

    /// Handle MCR p15, opcode1, Rd, CRn, CRm, opcode2
    func write(crn: Int, crm: Int, opcode2: Int, value: UInt32) {
        switch (crn, crm, opcode2) {
        // c1: Control register
        case (1, 0, 0):
            control = value

        // c2: Cachability (store but don't emulate)
        case (2, 0, 0), (2, 0, 1):
            break

        // c3: Write buffer (store but don't emulate)
        case (3, 0, 0):
            break

        // c5: Access permissions (store but don't emulate)
        case (5, _, _):
            break

        // c6: Protection Unit regions (store but don't emulate)
        case (6, _, _):
            break

        // c7: Cache operations
        case (7, _, _):
            // Cache flush/invalidate — no-op for interpreter
            break

        // c9: TCM configuration
        case (9, 1, 0):
            // DTCM Base & Size
            dtcmBase = value & 0xFFFF_F000
            let sizeField = (value >> 1) & 0x1F
            dtcmSize = sizeField >= 3 ? (512 << sizeField) : 16 * 1024

        case (9, 1, 1):
            // ITCM Size (base is always 0)
            let sizeField = (value >> 1) & 0x1F
            itcmSize = sizeField >= 3 ? (512 << sizeField) : 32 * 1024

        default:
            break
        }
    }

    // MARK: - Helpers

    /// Encode TCM config register value from base address and size
    private func encodeTCMConfig(base: UInt32, size: UInt32) -> UInt32 {
        var sizeField: UInt32 = 0
        var s = size
        if s >= 512 {
            while s > 512 {
                s >>= 1
                sizeField += 1
            }
            sizeField += 3
        }
        return (base & 0xFFFF_F000) | ((sizeField & 0x1F) << 1)
    }
}
