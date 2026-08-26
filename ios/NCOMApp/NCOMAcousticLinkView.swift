import SwiftUI
import AVFoundation

@MainActor
final class NCOMAcousticLink: ObservableObject {
    @Published private(set) var state = "Idle"
    @Published private(set) var lastPacket = ""
    @Published private(set) var receivedPackets: [String] = []
    private let audio = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    init() { audio.attach(player) }

    func prepare() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            if !audio.outputNode.isPlaying { audio.connect(player, to: audio.mainMixerNode, format: nil) }
            state = "Ready"
        } catch { state = "Audio unavailable: \(error.localizedDescription)" }
    }

    func send(_ message: String) {
        prepare()
        let packet = AcousticPacket.encode(message)
        lastPacket = packet
        let sampleRate = audio.outputNode.outputFormat(forBus: 0).sampleRate > 0 ? audio.outputNode.outputFormat(forBus: 0).sampleRate : 44_100
        let toneDuration = 0.055
        let mark = 18_200.0
        let space = 19_800.0
        let preamble = Array(repeating: true, count: 16)
        let bits = preamble + packet.utf8.flatMap { byte -> [Bool] in (0..<8).map { ((byte >> UInt8($0)) & 1) == 1 } }
        let samplesPerBit = Int(sampleRate * toneDuration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1), let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samplesPerBit * bits.count)) else { return }
        buffer.frameLength = buffer.frameCapacity
        let phaseIncrement: (Double) -> Double = { $0 * 2.0 * Double.pi / sampleRate }
        guard let channel = buffer.floatChannelData?[0] else { return }
        var index = 0
        for bit in bits {
            let frequency = bit ? mark : space
            for sample in 0..<samplesPerBit {
                let envelope = min(1.0, Double(sample) / 300.0, Double(samplesPerBit - sample) / 300.0)
                channel[index] = Float(sin(Double(sample) * phaseIncrement(frequency)) * 0.12 * envelope)
                index += 1
            }
        }
        audio.prepare()
        player.scheduleBuffer(buffer) { [weak self] in Task { @MainActor in self?.state = "Packet sent" } }
        player.play()
        state = "Transmitting"
    }

    func stop() { player.stop(); state = "Stopped" }
}

private enum AcousticPacket {
    static let version: UInt8 = 1
    static func encode(_ text: String) -> String {
        let payload = Data(text.utf8)
        let checksum = crc8(payload)
        var frame = Data([version])
        frame.append(UInt8(min(payload.count, 180)))
        frame.append(payload.prefix(180))
        frame.append(checksum)
        return frame.base64EncodedString()
    }
    static func crc8(_ data: Data) -> UInt8 { data.reduce(UInt8(0)) { value, byte in var crc = value ^ byte; for _ in 0..<8 { crc = (crc & 0x80) != 0 ? (crc << 1) ^ 0x07 : crc << 1 }; return crc } }
}

struct NCOMAcousticLinkView: View {
    @StateObject private var link = NCOMAcousticLink()
    @State private var text = "NCOM HAIL v1"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NCOMGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Image(systemName: "waveform").font(.title2); Text("Acoustic Link").font(.title2.bold()); Spacer(); Text(link.state).font(.caption).foregroundStyle(.secondary) }
                        Text("A short-range acoustic modem for exchanging signed/structured NCOM packets between cooperating devices or agents. This prototype uses audible carrier tones and a framed packet format.").font(.footnote).foregroundStyle(.secondary)
                        TextField("Message", text: $text, axis: .vertical).textFieldStyle(.roundedBorder)
                        HStack {
                            Button("Prepare") { link.prepare() }.buttonStyle(NCOMGlassButtonStyle())
                            Button("Transmit") { link.send(text) }.buttonStyle(NCOMGlassButtonStyle(prominent: true))
                            Button("Stop") { link.stop() }.buttonStyle(NCOMGlassButtonStyle())
                        }
                    }
                }
                if !link.lastPacket.isEmpty {
                    NCOMGlassCard {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("LAST PACKET").font(.caption.bold()).foregroundStyle(.secondary)
                            Text(link.lastPacket).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(NCOMBackground())
        .navigationTitle("Acoustic Link")
        .navigationBarTitleDisplayMode(.inline)
    }
}
