import AppKit

final class TypingAudioController {
    var isEnabled = true
    var volume: Float = 0.30
    var profile: TypingProfile = .soft

    private var sounds: [TypingProfile: [TypingKey: [NSSound]]] = [:]
    private var poolIndexes: [String: Int] = [:]

    init() {
        buildSoundPools()
    }

    func play(_ key: TypingKey) {
        guard isEnabled, let pool = sounds[profile]?[key], !pool.isEmpty else { return }
        let indexKey = "\(profile.rawValue)-\(String(describing: key))"
        let next = (poolIndexes[indexKey, default: -1] + 1) % pool.count
        poolIndexes[indexKey] = next
        let sound = pool[next]
        sound.volume = volume
        sound.play()
    }

    private func buildSoundPools() {
        for profile in TypingProfile.allCases {
            var byKey: [TypingKey: [NSSound]] = [:]
            for key in [TypingKey.character, .space, .returnKey, .delete] {
                byKey[key] = (0..<5).compactMap { variant in
                    NSSound(data: synthesize(profile: profile, key: key, variant: variant))
                }
            }
            sounds[profile] = byKey
        }
    }

    private func synthesize(profile: TypingProfile, key: TypingKey, variant: Int) -> Data {
        let sampleRate = 22_050
        let duration: Double = switch profile {
        case .soft: key == .returnKey ? 0.090 : (key == .space ? 0.050 : 0.045)
        case .classicMac: key == .returnKey ? 0.110 : (key == .space ? 0.065 : 0.052)
        case .pc: key == .returnKey ? 0.125 : (key == .space ? 0.078 : 0.060)
        case .terminal: key == .returnKey ? 0.095 : (key == .delete ? 0.070 : 0.045)
        case .typewriter: key == .returnKey ? 0.380 : (key == .delete ? 0.120 : (key == .space ? 0.075 : 0.082))
        case .wooden: key == .returnKey ? 0.145 : (key == .space ? 0.080 : 0.070)
        case .space: key == .returnKey ? 0.180 : (key == .space ? 0.100 : 0.090)
        case .cyber: key == .returnKey ? 0.140 : (key == .delete ? 0.095 : 0.062)
        case .hell: key == .returnKey ? 0.360 : (key == .space ? 0.145 : 0.105)
        case .liquid: key == .returnKey ? 0.190 : (key == .space ? 0.120 : 0.135)
        }
        let count = Int(Double(sampleRate) * duration)
        var samples = [Int16]()
        samples.reserveCapacity(count)
        var seed = UInt32(0xA341_316C &+ UInt32(variant * 7919) &+ UInt32(profile.rawValue.utf8.reduce(0, { Int($0) + Int($1) })))

        for index in 0..<count {
            seed = 1_664_525 &* seed &+ 1_013_904_223
            let noise = Double(Int32(bitPattern: seed)) / Double(Int32.max)
            let t = Double(index) / Double(sampleRate)
            let progress = Double(index) / Double(max(count - 1, 1))
            let keyPitch: Double = key == .space ? 0.72 : (key == .delete ? 0.84 : 1)
            let variantPitch = 1 + Double(variant - 2) * 0.018
            func pulse(_ center: Double, width: Double) -> Double {
                exp(-pow((t - center) / width, 2))
            }
            func ring(_ frequency: Double, decay: Double, delay: Double = 0) -> Double {
                guard t >= delay else { return 0 }
                let local = t - delay
                return sin(2 * .pi * frequency * variantPitch * local) * exp(-local * decay)
            }
            let strike = pulse(0.0035, width: 0.0018)
            let value: Double
            switch profile {
            case .soft:
                let felt = noise * 0.17 * exp(-t * 95) + ring(410 * keyPitch, decay: 82) * 0.12
                let body = ring(key == .space ? 150 : 235, decay: 55) * (key == .returnKey ? 0.18 : 0.08)
                value = felt + body
            case .classicMac:
                let plasticSnap = strike * noise * 0.66 + ring(2_180 * keyPitch, decay: 105) * 0.17
                let hollowCase = ring(key == .space ? 235 : 430, decay: key == .returnKey ? 34 : 62) * (key == .returnKey ? 0.32 : 0.15)
                value = plasticSnap + hollowCase
            case .pc:
                let buckle = pulse(0.0045, width: 0.0013) * (noise * 0.76 + ring(3_050 * keyPitch, decay: 120) * 0.22)
                let spring = ring(1_260 * keyPitch, decay: 47) * 0.27
                let chassis = ring(key == .space ? 118 : 205, decay: key == .returnKey ? 25 : 42) * (key == .returnKey ? 0.36 : 0.13)
                value = buckle + spring + chassis
            case .terminal:
                let drySwitch = strike * noise * 0.58
                let square = sin(2 * .pi * 1_860 * keyPitch * variantPitch * t) >= 0 ? 1.0 : -1.0
                let logicTick = square * 0.105 * exp(-t * 150)
                let terminalCase = ring(key == .returnKey ? 92 : 360, decay: key == .returnKey ? 32 : 88) * (key == .returnKey ? 0.30 : 0.11)
                value = drySwitch + logicTick + terminalCase
            case .typewriter:
                if key == .returnKey {
                    let lever = pulse(0.008, width: 0.004) * (noise * 0.48 + ring(112, decay: 58) * 0.34)
                    let sweepWindow = t >= 0.025 && t <= 0.275 ? sin(.pi * (t - 0.025) / 0.25) : 0
                    let carriage = noise * 0.055 * sweepWindow
                    var ratchet = 0.0
                    for step in 0..<8 {
                        let center = 0.050 + Double(step) * 0.026
                        ratchet += pulse(center, width: 0.0019) * (noise * 0.31 + sin(2 * .pi * Double(820 + step * 43) * t) * 0.17)
                    }
                    let stop = pulse(0.300, width: 0.0065) * (noise * 0.42 + ring(86, decay: 52, delay: 0.294) * 0.42)
                    value = lever + carriage + ratchet + stop
                } else if key == .delete {
                    var reverseRatchet = 0.0
                    for step in 0..<3 {
                        reverseRatchet += pulse(0.010 + Double(step) * 0.023, width: 0.002) * (noise * 0.40 + ring(Double(1_150 - step * 120), decay: 85, delay: 0.008 + Double(step) * 0.023) * 0.16)
                    }
                    value = reverseRatchet + ring(145, decay: 38) * 0.11
                } else {
                    let slug = strike * noise * (key == .space ? 0.34 : 0.72)
                    let metal = ring((key == .space ? 690 : 2_120) * keyPitch, decay: key == .space ? 76 : 92) * (key == .space ? 0.13 : 0.22)
                    let paper = ring(key == .space ? 135 : 188, decay: 48) * (key == .space ? 0.16 : 0.20)
                    value = slug + metal + paper
                }
            case .wooden:
                let deskKnock = strike * noise * 0.27 + ring(210 * keyPitch, decay: 38) * 0.38
                let woodOvertone = ring(610 * keyPitch, decay: 66) * 0.15
                let bookRoom = key == .returnKey ? ring(92, decay: 24, delay: 0.030) * 0.22 : 0
                value = deskKnock + woodOvertone + bookRoom
            case .space:
                let relay = strike * noise * 0.30 + ring(1_540 * keyPitch, decay: 37) * 0.20
                let solenoid = ring(key == .space ? 180 : 330, decay: 48) * 0.18
                let consoleConfirm = key == .returnKey ? ring(740, decay: 16, delay: 0.035) * 0.17 : 0
                value = relay + solenoid + consoleConfirm
            case .cyber:
                let switchClick = strike * noise * 0.45 + ring(760 * keyPitch, decay: 78) * 0.17
                let relayBody = ring(168 * keyPitch, decay: 45) * 0.24
                let chirpFrequency = (1_380 + progress * 520) * variantPitch
                let dataChirp = sin(2 * .pi * chirpFrequency * t) * exp(-t * 68) * (key == .returnKey ? 0.16 : 0.075)
                let confirm = key == .returnKey ? ring(390, decay: 18, delay: 0.045) * 0.17 : 0
                value = switchClick + relayBody + dataChirp + confirm
            case .hell:
                let ironStrike = strike * noise * 0.52 + ring(174 * keyPitch, decay: 36) * 0.30
                let cavern = ring(55 * keyPitch, decay: key == .returnKey ? 8 : 18) * (key == .returnKey ? 0.48 : 0.25)
                let corrodedRing = ring(410 * keyPitch, decay: 24) * 0.12
                var din = 0.0
                if key == .returnKey {
                    for step in 0..<3 {
                        let center = 0.020 + Double(step) * 0.065
                        din += pulse(center, width: 0.007) * (noise * 0.34 + ring(Double(118 - step * 18), decay: 24, delay: center) * 0.26)
                    }
                    din += noise * 0.035 * exp(-t * 9)
                } else if key == .space {
                    for step in 0..<4 { din += pulse(0.009 + Double(step) * 0.013, width: 0.002) * noise * 0.17 }
                }
                value = ironStrike + cavern + corrodedRing + din
            case .liquid:
                let dropFrequency = (1_140 - progress * 520) * keyPitch * variantPitch
                let drop = sin(2 * .pi * dropFrequency * t) * exp(-t * (key == .returnKey ? 18 : 30)) * 0.22
                let glass = ring(key == .space ? 620 : 1_820, decay: key == .returnKey ? 14 : 24, delay: 0.012) * (key == .returnKey ? 0.15 : 0.09)
                let surface = strike * noise * 0.10
                value = drop + glass + surface
            }
            samples.append(Int16(max(-1, min(1, value)) * Double(Int16.max) * 0.64))
        }
        return makeWave(samples: samples, sampleRate: sampleRate)
    }

    private func makeWave(samples: [Int16], sampleRate: Int) -> Data {
        let byteCount = UInt32(samples.count * MemoryLayout<Int16>.size)
        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.appendLittleEndian(UInt32(36) + byteCount)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * 2))
        data.appendLittleEndian(UInt16(2))
        data.appendLittleEndian(UInt16(16))
        data.append("data".data(using: .ascii)!)
        data.appendLittleEndian(byteCount)
        for sample in samples { data.appendLittleEndian(sample) }
        return data
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { bytes in
            append(contentsOf: bytes)
        }
    }
}
