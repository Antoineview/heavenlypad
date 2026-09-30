// HeavenlyPad/Core/Cartridge/NDSLoader.swift
// NDS ROM file parser and loader

import Foundation

/// Errors that can occur during ROM loading
enum NDSError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case invalidROM(String)
    case loadFailed(String)

    var description: String {
        switch self {
        case .fileNotFound(let msg): return "File not found: \(msg)"
        case .invalidROM(let msg): return "Invalid ROM: \(msg)"
        case .loadFailed(let msg): return "Load failed: \(msg)"
        }
    }
}

/// Parsed NDS ROM header (first 0x200 bytes)
struct NDSHeader {
    let gameTitle: String       // 0x000: 12 bytes ASCII
    let gameCode: String        // 0x00C: 4 bytes
    let makerCode: String       // 0x010: 2 bytes
    let unitCode: UInt8         // 0x012: 0=NDS, 2=NDS+DSi, 3=DSi
    let arm9RomOffset: UInt32   // 0x020
    let arm9EntryAddress: UInt32 // 0x024
    let arm9RamAddress: UInt32  // 0x028
    let arm9Size: UInt32        // 0x02C
    let arm7RomOffset: UInt32   // 0x030
    let arm7EntryAddress: UInt32 // 0x034
    let arm7RamAddress: UInt32  // 0x038
    let arm7Size: UInt32        // 0x03C
    let fntOffset: UInt32       // 0x040
    let fntSize: UInt32         // 0x044
    let fatOffset: UInt32       // 0x048
    let fatSize: UInt32         // 0x04C
    let arm9OverlayOffset: UInt32  // 0x050
    let arm9OverlaySize: UInt32    // 0x054
    let arm7OverlayOffset: UInt32  // 0x058
    let arm7OverlaySize: UInt32    // 0x05C
    let iconOffset: UInt32         // 0x068
    let headerCRC16: UInt16        // 0x15E
}

/// NDS ROM loader — parses header and loads ARM9/ARM7 binaries into memory
final class NDSLoader {
    let romData: Data
    let header: NDSHeader

    /// Load an NDS ROM from a file URL
    init(url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NDSError.fileNotFound(url.path)
        }

        romData = try Data(contentsOf: url)

        guard romData.count >= 0x200 else {
            throw NDSError.invalidROM("File too small for NDS header (\(romData.count) bytes)")
        }

        header = NDSLoader.parseHeader(romData)

        // Validate Nintendo logo CRC
        guard romData.count > Int(header.arm9RomOffset) + Int(header.arm9Size) else {
            throw NDSError.invalidROM("ROM too small for ARM9 binary")
        }
        guard romData.count > Int(header.arm7RomOffset) + Int(header.arm7Size) else {
            throw NDSError.invalidROM("ROM too small for ARM7 binary")
        }
    }

    /// Parse the 512-byte NDS header from ROM data
    static func parseHeader(_ data: Data) -> NDSHeader {
        return NDSHeader(
            gameTitle: readASCII(data, offset: 0x000, length: 12),
            gameCode: readASCII(data, offset: 0x00C, length: 4),
            makerCode: readASCII(data, offset: 0x010, length: 2),
            unitCode: data[0x012],
            arm9RomOffset: readU32(data, 0x020),
            arm9EntryAddress: readU32(data, 0x024),
            arm9RamAddress: readU32(data, 0x028),
            arm9Size: readU32(data, 0x02C),
            arm7RomOffset: readU32(data, 0x030),
            arm7EntryAddress: readU32(data, 0x034),
            arm7RamAddress: readU32(data, 0x038),
            arm7Size: readU32(data, 0x03C),
            fntOffset: readU32(data, 0x040),
            fntSize: readU32(data, 0x044),
            fatOffset: readU32(data, 0x048),
            fatSize: readU32(data, 0x04C),
            arm9OverlayOffset: readU32(data, 0x050),
            arm9OverlaySize: readU32(data, 0x054),
            arm7OverlayOffset: readU32(data, 0x058),
            arm7OverlaySize: readU32(data, 0x05C),
            iconOffset: readU32(data, 0x068),
            headerCRC16: readU16(data, 0x15E)
        )
    }

    // MARK: - Binary Loading

    /// Load the ARM9 binary into the bus memory
    func loadARM9Into(memory: UnsafeMutableRawPointer, baseAddress: UInt32) {
        let start = Int(header.arm9RomOffset)
        let size = Int(header.arm9Size)
        let ramOffset = Int(header.arm9RamAddress - baseAddress)

        romData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let src = ptr.baseAddress else { return }
            memory.advanced(by: ramOffset)
                .copyMemory(from: src.advanced(by: start), byteCount: size)
        }
    }

    /// Load the ARM7 binary into the bus memory
    func loadARM7Into(memory: UnsafeMutableRawPointer, baseAddress: UInt32) {
        let start = Int(header.arm7RomOffset)
        let size = Int(header.arm7Size)
        let ramOffset = Int(header.arm7RamAddress - baseAddress)

        romData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let src = ptr.baseAddress else { return }
            memory.advanced(by: ramOffset)
                .copyMemory(from: src.advanced(by: start), byteCount: size)
        }
    }

    /// Load ARM9 overlay table entries
    func loadARM9Overlays(memory: UnsafeMutableRawPointer, baseAddress: UInt32) {
        guard header.arm9OverlaySize > 0 else { return }

        let tableStart = Int(header.arm9OverlayOffset)
        let entrySize = 32  // Each overlay table entry is 32 bytes
        let entryCount = Int(header.arm9OverlaySize) / entrySize

        for i in 0..<entryCount {
            let entryOffset = tableStart + i * entrySize
            let ramAddress = readU32(romData, entryOffset + 4)  // Load address
            let ramSize = readU32(romData, entryOffset + 8)     // Size
            let fileID = readU32(romData, entryOffset + 24)     // File ID

            // Look up file in FAT to get ROM offset
            let fatEntryOffset = Int(header.fatOffset) + Int(fileID) * 8
            let romOffset = Int(readU32(romData, fatEntryOffset))
            let romEnd = Int(readU32(romData, fatEntryOffset + 4))
            let overlaySize = min(Int(ramSize), romEnd - romOffset)

            let ramDest = Int(ramAddress - baseAddress)
            guard ramDest >= 0 && ramDest + overlaySize <= 4 * 1024 * 1024 else { continue }

            romData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                guard let src = ptr.baseAddress else { return }
                memory.advanced(by: ramDest)
                    .copyMemory(from: src.advanced(by: romOffset), byteCount: overlaySize)
            }
        }
    }

    // MARK: - Helper Functions

    private static func readASCII(_ data: Data, offset: Int, length: Int) -> String {
        let bytes = data[offset..<(offset + length)]
        let str = String(bytes: bytes, encoding: .ascii) ?? ""
        // Trim null bytes
        return str.replacingOccurrences(of: "\0", with: "").trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Data Reading Helpers

func readU32(_ data: Data, _ offset: Int) -> UInt32 {
    guard offset + 3 < data.count else { return 0 }
    return data.withUnsafeBytes { ptr in
        ptr.load(fromByteOffset: offset, as: UInt32.self)
    }
}

func readU16(_ data: Data, _ offset: Int) -> UInt16 {
    guard offset + 1 < data.count else { return 0 }
    return data.withUnsafeBytes { ptr in
        ptr.load(fromByteOffset: offset, as: UInt16.self)
    }
}
