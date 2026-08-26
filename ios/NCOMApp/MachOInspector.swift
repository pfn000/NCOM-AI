import Foundation

struct MachOInspection: Sendable, Codable {
    let magic: String
    let architecture: String
    let fileType: UInt32
    let flags: UInt32
    let commandCount: UInt32
    let commands: [MachOCommand]
    let asciiStrings: [String]
}

struct MachOCommand: Sendable, Codable {
    let id: UInt32
    let size: UInt32
    let offset: Int
    let segmentName: String?
    let virtualAddress: UInt64?
    let virtualSize: UInt64?
}

enum MachOInspector {
    enum Error: LocalizedError {
        case tooSmall
        case unsupportedMagic(UInt32)
        case malformedCommand

        var errorDescription: String? {
            switch self {
            case .tooSmall: return "File is too small to contain a Mach-O header."
            case .unsupportedMagic(let value): return String(format: "Unsupported Mach-O magic 0x%08X.", value)
            case .malformedCommand: return "Mach-O load command is malformed or extends past the file."
            }
        }
    }

    static func inspect(url: URL, stringMinimumLength: Int = 4) throws -> MachOInspection {
        let data = try Data(contentsOf: url)
        return try parse(data: data, stringMinimumLength: stringMinimumLength)
    }

    static func parse(data: Data, stringMinimumLength: Int = 4) throws -> MachOInspection {
        guard data.count >= 32 else { throw Error.tooSmall }

        let rawMagic = readUInt32(data, at: 0, littleEndian: true)
        let (magicName, is64, littleEndian) = try decodeMagic(rawMagic)
        let commandCount = readUInt32(data, at: 16, littleEndian: littleEndian)
        let headerSize = is64 ? 32 : 28
        guard data.count >= headerSize else { throw Error.tooSmall }

        let fileType = readUInt32(data, at: 12, littleEndian: littleEndian)
        let flagsOffset = is64 ? 24 : 24
        let flags = readUInt32(data, at: flagsOffset, littleEndian: littleEndian)
        var commands: [MachOCommand] = []
        var offset = headerSize

        for _ in 0..<commandCount {
            guard offset + 8 <= data.count else { throw Error.malformedCommand }
            let cmd = readUInt32(data, at: offset, littleEndian: littleEndian)
            let size = readUInt32(data, at: offset + 4, littleEndian: littleEndian)
            guard size >= 8, offset + Int(size) <= data.count else { throw Error.malformedCommand }

            var segmentName: String?
            var virtualAddress: UInt64?
            var virtualSize: UInt64?
            let commandWithoutRequiredBits = cmd & ~UInt32(0x80000000)
            if is64 && commandWithoutRequiredBits == 0x19 && size >= 72 {
                segmentName = readFixedCString(data, at: offset + 8, length: 16)
                virtualAddress = readUInt64(data, at: offset + 24, littleEndian: littleEndian)
                virtualSize = readUInt64(data, at: offset + 32, littleEndian: littleEndian)
            } else if !is64 && commandWithoutRequiredBits == 0x1 && size >= 56 {
                segmentName = readFixedCString(data, at: offset + 8, length: 16)
                virtualAddress = UInt64(readUInt32(data, at: offset + 24, littleEndian: littleEndian))
                virtualSize = UInt64(readUInt32(data, at: offset + 28, littleEndian: littleEndian))
            }

            commands.append(MachOCommand(id: cmd, size: size, offset: offset, segmentName: segmentName, virtualAddress: virtualAddress, virtualSize: virtualSize))
            offset += Int(size)
        }

        return MachOInspection(
            magic: magicName,
            architecture: is64 ? "64-bit" : "32-bit",
            fileType: fileType,
            flags: flags,
            commandCount: commandCount,
            commands: commands,
            asciiStrings: extractStrings(data: data, minimumLength: stringMinimumLength)
        )
    }

    static func extractStrings(data: Data, minimumLength: Int = 4) -> [String] {
        guard minimumLength > 0 else { return [] }
        var output: [String] = []
        var current: [UInt8] = []

        func flush() {
            guard current.count >= minimumLength else { current.removeAll(keepingCapacity: true); return }
            output.append(String(decoding: current, as: UTF8.self))
            current.removeAll(keepingCapacity: true)
        }

        for byte in data {
            if (32...126).contains(byte) { current.append(byte) }
            else { flush() }
        }
        flush()
        return output
    }

    private static func decodeMagic(_ magic: UInt32) throws -> (String, Bool, Bool) {
        switch magic {
        case 0xfeedfacf: return ("MH_MAGIC_64", true, true)
        case 0xcffaedfe: return ("MH_CIGAM_64", true, false)
        case 0xfeedface: return ("MH_MAGIC", false, true)
        case 0xcefaedfe: return ("MH_CIGAM", false, false)
        default: throw Error.unsupportedMagic(magic)
        }
    }

    private static func readUInt32(_ data: Data, at offset: Int, littleEndian: Bool) -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { return 0 }
        let bytes = Array(data[offset..<(offset + 4)])
        let value = UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
        return littleEndian ? value : value.byteSwapped
    }

    private static func readUInt64(_ data: Data, at offset: Int, littleEndian: Bool) -> UInt64 {
        guard offset >= 0, offset + 8 <= data.count else { return 0 }
        var value: UInt64 = 0
        for index in 0..<8 { value |= UInt64(data[offset + index]) << UInt64(index * 8) }
        return littleEndian ? value : value.byteSwapped
    }

    private static func readFixedCString(_ data: Data, at offset: Int, length: Int) -> String {
        guard offset >= 0, offset + length <= data.count else { return "" }
        let bytes = Array(data[offset..<(offset + length)])
        let usable = bytes.prefix { $0 != 0 }
        return String(decoding: usable, as: UTF8.self)
    }
}
