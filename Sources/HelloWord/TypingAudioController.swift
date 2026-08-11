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
            if profile == .typewriter, let recorded = recordedTypewriterPools() {
                sounds[profile] = recorded
                continue
            }
            var byKey: [TypingKey: [NSSound]] = [:]
            for key in [TypingKey.character, .space, .returnKey, .delete] {
                byKey[key] = (0..<5).compactMap { variant in
                    NSSound(data: synthesize(profile: profile, key: key, variant: variant))
                }
            }
            sounds[profile] = byKey
        }
    }

    private func recordedTypewriterPools() -> [TypingKey: [NSSound]]? {
        func sound(_ name: String) -> NSSound? {
            guard let url = Bundle.main.url(
                forResource: name,
                withExtension: "wav",
                subdirectory: "Typing Sounds/typewriter"
            ) else { return nil }
            return NSSound(contentsOf: url, byReference: false)
        }

        let characters = (1...5).compactMap { sound("character-\($0)") }
        guard characters.count == 5,
              let space = sound("space-1"),
              let carriageReturn = sound("return-1"),
              let delete = sound("delete-1") else { return nil }
        return [
            .character: characters,
            .space: [space],
            .returnKey: [carriageReturn],
            .delete: [delete]
        ]
    }

    private func synthesize(profile: TypingProfile, key: TypingKey, variant: Int) -> Data {
        let sampleRate = 22_050
        let duration: Double
        switch profile {
        case .soft: duration = key == .returnKey ? 0.085 : 0.050
        case .classicMac: duration = key == .returnKey ? 0.105 : 0.060
        case .pc: duration = key == .returnKey ? 0.135 : 0.070
        case .terminal: duration = key == .returnKey ? 0.095 : 0.050
        case .typewriter: duration = key == .returnKey ? 0.460 : 0.095
        case .wooden: duration = key == .returnKey ? 0.120 : 0.065
        case .space: duration = key == .returnKey ? 0.180 : 0.090
        case .cyber: duration = key == .returnKey ? 0.120 : 0.060
        case .hell: duration = key == .returnKey ? 0.240 : 0.075
        case .liquid: duration = key == .returnKey ? 0.115 : 0.070
        }
        let count = Int(Double(sampleRate) * duration)
        var samples = [Int16]()
        samples.reserveCapacity(count)
        var seed = UInt32(0xA341_316C &+ UInt32(variant * 7919) &+ UInt32(profile.rawValue.utf8.reduce(0, { Int($0) + Int($1) })))
        var lowNoise = 0.0
        var veryLowNoise = 0.0

        for index in 0..<count {
            seed = 1_664_525 &* seed &+ 1_013_904_223
            let noise = Double(Int32(bitPattern: seed)) / Double(Int32.max)
            let t = Double(index) / Double(sampleRate)
            lowNoise = lowNoise * 0.76 + noise * 0.24
            veryLowNoise = veryLowNoise * 0.93 + noise * 0.07
            let highNoise = noise - lowNoise
            let middleNoise = lowNoise - veryLowNoise
            let jitter = Double(variant - 2) * 0.00016
            func pulse(_ center: Double, width: Double) -> Double {
                exp(-pow((t - center - jitter) / width, 2))
            }
            let value: Double
            switch profile {
            case .soft:
                let felt = pulse(0.0035, width: 0.0022) * lowNoise * 0.42
                let release = pulse(0.014, width: 0.0042) * middleNoise * 0.18
                value = felt + release + (key == .returnKey ? pulse(0.038, width: 0.010) * veryLowNoise * 0.24 : 0)
            case .classicMac:
                let plasticDown = pulse(0.0032, width: 0.0012) * highNoise * 1.15
                let plasticUp = pulse(0.018, width: 0.0022) * highNoise * 0.58
                let adbCase = pulse(key == .space ? 0.010 : 0.007, width: key == .space ? 0.008 : 0.004) * middleNoise * 0.50
                value = plasticDown + plasticUp + adbCase + (key == .returnKey ? pulse(0.048, width: 0.011) * lowNoise * 0.48 : 0)
            case .pc:
                let buckle = pulse(0.0035, width: 0.0010) * highNoise * 1.35
                let springSnap = pulse(0.0095, width: 0.0015) * highNoise * 0.88
                let upstroke = pulse(0.025, width: 0.0024) * highNoise * 0.48
                let chassis = pulse(0.012, width: key == .space ? 0.012 : 0.006) * veryLowNoise * (key == .returnKey ? 0.95 : 0.55)
                value = buckle + springSnap + upstroke + chassis
            case .terminal:
                let switchDown = pulse(0.0028, width: 0.0009) * highNoise * 1.30
                let relay = pulse(0.0075, width: 0.0012) * middleNoise * 0.72
                let switchUp = pulse(0.021, width: 0.0014) * highNoise * 0.45
                value = switchDown + relay + switchUp + (key == .returnKey ? pulse(0.050, width: 0.009) * lowNoise * 0.62 : 0)
            case .typewriter:
                if key == .returnKey {
                    let lever = pulse(0.008, width: 0.0035) * (highNoise * 0.85 + middleNoise * 0.45)
                    let sweepWindow = t >= 0.028 && t <= 0.330 ? sin(.pi * (t - 0.028) / 0.302) : 0
                    let carriage = (highNoise * 0.10 + middleNoise * 0.08) * sweepWindow
                    var ratchet = 0.0
                    for step in 0..<10 {
                        ratchet += pulse(0.055 + Double(step) * 0.026, width: 0.0017) * highNoise * 0.55
                    }
                    let stop = pulse(0.354, width: 0.0065) * (highNoise * 0.75 + veryLowNoise * 0.82)
                    value = lever + carriage + ratchet + stop
                } else {
                    let typebar = pulse(0.0032, width: 0.0010) * highNoise * (key == .space ? 0.48 : 1.25)
                    let ribbonPaper = pulse(0.0062, width: 0.0020) * middleNoise * (key == .space ? 0.52 : 0.90)
                    let mechanism = pulse(0.015, width: 0.004) * veryLowNoise * 0.42
                    value = typebar + ribbonPaper + mechanism
                }
            case .wooden:
                let feltKey = pulse(0.0038, width: 0.0018) * highNoise * 0.56
                let oakKnock = pulse(0.009, width: 0.0065) * veryLowNoise * (key == .space ? 0.78 : 0.56)
                let release = pulse(0.027, width: 0.004) * middleNoise * 0.22
                value = feltKey + oakKnock + release + (key == .returnKey ? pulse(0.065, width: 0.014) * lowNoise * 0.35 : 0)
            case .space:
                let relay = pulse(0.003, width: 0.0012) * highNoise * 0.65
                let oscillator = sin(2 * .pi * (key == .space ? 420 : 1_280) * t) * exp(-t * 42) * 0.19
                let confirm = key == .returnKey && t > 0.035
                    ? sin(2 * .pi * 680 * (t - 0.035)) * exp(-(t - 0.035) * 22) * 0.16
                    : 0
                value = relay + oscillator + confirm
            case .cyber:
                let hardSwitch = pulse(0.0028, width: 0.0008) * highNoise * 1.18
                let opticalGate = pulse(0.007, width: 0.0010) * highNoise * 0.70
                var zipper = 0.0
                for step in 0..<(key == .returnKey ? 5 : 2) {
                    zipper += pulse(0.016 + Double(step) * 0.009, width: 0.0008) * highNoise * 0.28
                }
                value = hardSwitch + opticalGate + zipper + pulse(0.012, width: 0.005) * middleNoise * 0.33
            case .hell:
                if key == .returnKey {
                    let lever = pulse(0.004, width: 0.0016) * highNoise * 0.95
                    var ironRatchet = 0.0
                    for step in 0..<6 {
                        ironRatchet += pulse(0.024 + Double(step) * 0.021, width: 0.0015) * (highNoise * 0.58 + middleNoise * 0.24)
                    }
                    let stop = pulse(0.170, width: 0.009) * (middleNoise * 0.55 + veryLowNoise * 0.92)
                    value = lever + ironRatchet + stop
                } else {
                    let boneKey = pulse(0.0032, width: 0.0011) * highNoise * 0.92
                    let ironBody = pulse(0.0075, width: key == .space ? 0.006 : 0.0035) * middleNoise * 0.52
                    let release = pulse(0.025, width: 0.0020) * highNoise * 0.28
                    value = boneKey + ironBody + release
                }
            case .liquid:
                let surfaceTap = pulse(0.003, width: 0.0011) * highNoise * 0.58
                let fluidBody = pulse(0.009, width: 0.005) * lowNoise * 0.30
                let tinyRipple = pulse(0.026, width: 0.008) * middleNoise * (key == .returnKey ? 0.34 : 0.16)
                value = surfaceTap + fluidBody + tinyRipple
            }
            samples.append(Int16(max(-1, min(1, value)) * Double(Int16.max) * 0.72))
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
