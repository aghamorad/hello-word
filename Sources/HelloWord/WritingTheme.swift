import AppKit

enum ThemeID: String, CaseIterable, Codable {
    case calm
    case mac1999
    case system95
    case dos
    case typewriter
    case library
    case spaceAge
    case cyberdeck
    case hell
    case liquidGlass
}

enum TypingProfile: String, CaseIterable {
    case soft
    case classicMac
    case pc
    case terminal
    case typewriter
    case wooden
    case space
    case cyber
    case hell
    case liquid
}

struct WritingTheme {
    let id: ThemeID
    let name: String
    let subtitle: String
    let textColor: NSColor
    let insertionColor: NSColor
    let editorColor: NSColor
    let defaultFontNames: [String]
    let defaultFontSize: CGFloat
    let lineSpacing: CGFloat
    let typingProfile: TypingProfile
    let prefersPixelEdges: Bool

    func font(size: CGFloat? = nil) -> NSFont {
        let pointSize = size ?? defaultFontSize
        for name in defaultFontNames {
            if let font = NSFont(name: name, size: pointSize) {
                return font
            }
        }
        if id == .dos || id == .mac1999 || id == .system95 {
            return .monospacedSystemFont(ofSize: pointSize, weight: .regular)
        }
        return .systemFont(ofSize: pointSize)
    }

    func persianFont(size: CGFloat? = nil) -> NSFont {
        let pointSize = size ?? defaultFontSize
        let candidates: [String]
        switch id {
        case .typewriter, .library, .hell:
            candidates = ["Vazirmatn", "Noto Naskh Arabic", "B Nazanin", "Geeza Pro", "Al Bayan", "Damascus"]
        case .mac1999, .system95, .dos:
            candidates = ["Noto Sans Arabic", "Vazirmatn", "Tahoma", "Arial", "Geeza Pro", "Damascus"]
        case .cyberdeck:
            candidates = ["Lalezar", "Vazirmatn", "Noto Sans Arabic", "Geeza Pro", "Damascus"]
        case .spaceAge, .liquidGlass, .calm:
            candidates = ["SF Arabic", "Vazirmatn", "Noto Sans Arabic", "Geeza Pro", "Damascus", "Arial"]
        }
        for name in candidates {
            if let font = NSFont(name: name, size: pointSize) { return font }
        }
        return NSFont.systemFont(ofSize: pointSize)
    }
}

extension WritingTheme {
    static let all: [WritingTheme] = [
        WritingTheme(
            id: .calm,
            name: "Still",
            subtitle: "Dawn, distance, and room to breathe",
            textColor: NSColor(calibratedWhite: 0.11, alpha: 1),
            insertionColor: NSColor(calibratedRed: 0.30, green: 0.23, blue: 0.15, alpha: 1),
            editorColor: NSColor(calibratedWhite: 1, alpha: 0.64),
            defaultFontNames: ["New York", "Charter", "Palatino"],
            defaultFontSize: 22,
            lineSpacing: 8,
            typingProfile: .soft,
            prefersPixelEdges: false
        ),
        WritingTheme(
            id: .mac1999,
            name: "Macintosh 1999",
            subtitle: "A complete platinum writing machine",
            textColor: NSColor(calibratedWhite: 0.08, alpha: 1),
            insertionColor: .black,
            editorColor: NSColor(calibratedWhite: 0.93, alpha: 1),
            defaultFontNames: ["Charcoal", "Chicago", "Monaco"],
            defaultFontSize: 18,
            lineSpacing: 5,
            typingProfile: .classicMac,
            prefersPixelEdges: true
        ),
        WritingTheme(
            id: .system95,
            name: "System 95",
            subtitle: "A maximised 1990s writing desktop",
            textColor: .black,
            insertionColor: .black,
            editorColor: .white,
            defaultFontNames: ["Tahoma", "Arial", "Geneva"],
            defaultFontSize: 19,
            lineSpacing: 5,
            typingProfile: .pc,
            prefersPixelEdges: true
        ),
        WritingTheme(
            id: .dos,
            name: "DOS Midnight",
            subtitle: "Nothing exists beyond the terminal",
            textColor: NSColor(calibratedRed: 0.35, green: 0.95, blue: 0.58, alpha: 1),
            insertionColor: NSColor(calibratedRed: 0.65, green: 1, blue: 0.74, alpha: 1),
            editorColor: NSColor(calibratedRed: 0.01, green: 0.025, blue: 0.045, alpha: 0.90),
            defaultFontNames: ["Perfect DOS VGA 437", "PxPlus IBM VGA8", "Menlo", "Monaco"],
            defaultFontSize: 19,
            lineSpacing: 4,
            typingProfile: .terminal,
            prefersPixelEdges: true
        ),
        WritingTheme(
            id: .typewriter,
            name: "Typewriter",
            subtitle: "Paper seated in a real writing machine",
            textColor: NSColor(calibratedRed: 0.11, green: 0.095, blue: 0.075, alpha: 1),
            insertionColor: NSColor(calibratedRed: 0.27, green: 0.12, blue: 0.07, alpha: 1),
            editorColor: .clear,
            defaultFontNames: ["American Typewriter", "Courier Prime", "Courier"],
            defaultFontSize: 20,
            lineSpacing: 7,
            typingProfile: .typewriter,
            prefersPixelEdges: false
        ),
        WritingTheme(
            id: .library,
            name: "Midnight Library",
            subtitle: "Rain, lamplight, and books after hours",
            textColor: NSColor(calibratedRed: 0.96, green: 0.90, blue: 0.72, alpha: 1),
            insertionColor: NSColor(calibratedRed: 1, green: 0.72, blue: 0.30, alpha: 1),
            editorColor: .clear,
            defaultFontNames: ["Iowan Old Style", "Baskerville", "Georgia"],
            defaultFontSize: 21,
            lineSpacing: 8,
            typingProfile: .wooden,
            prefersPixelEdges: false
        ),
        WritingTheme(
            id: .spaceAge,
            name: "Space Age 1968",
            subtitle: "Write from an orbital word deck",
            textColor: NSColor(calibratedRed: 1, green: 0.94, blue: 0.78, alpha: 1),
            insertionColor: NSColor(calibratedRed: 1, green: 0.47, blue: 0.16, alpha: 1),
            editorColor: .clear,
            defaultFontNames: ["Futura", "Avenir Next", "Helvetica Neue"],
            defaultFontSize: 20,
            lineSpacing: 7,
            typingProfile: .space,
            prefersPixelEdges: false
        ),
        WritingTheme(
            id: .cyberdeck,
            name: "Cyberdeck 2088",
            subtitle: "A neon city wired directly into the page",
            textColor: NSColor(calibratedRed: 0.76, green: 1, blue: 0.96, alpha: 1),
            insertionColor: NSColor(calibratedRed: 1, green: 0.16, blue: 0.68, alpha: 1),
            editorColor: .clear,
            defaultFontNames: ["SFMono-Regular", "JetBrainsMono-Regular", "Menlo", "Monaco"],
            defaultFontSize: 19,
            lineSpacing: 7,
            typingProfile: .cyber,
            prefersPixelEdges: true
        ),
        WritingTheme(
            id: .hell,
            name: "Hell",
            subtitle: "The page survives the fire",
            textColor: NSColor(calibratedRed: 0.92, green: 0.86, blue: 0.76, alpha: 1),
            insertionColor: NSColor(calibratedRed: 0.72, green: 0.065, blue: 0.035, alpha: 1),
            editorColor: .clear,
            defaultFontNames: ["Iowan Old Style", "Baskerville", "Cochin", "Georgia"],
            defaultFontSize: 22,
            lineSpacing: 8,
            typingProfile: .hell,
            prefersPixelEdges: false
        ),
        WritingTheme(
            id: .liquidGlass,
            name: "Liquid Glass",
            subtitle: "Your real Mac, visible through living glass",
            textColor: NSColor(calibratedWhite: 0.08, alpha: 0.96),
            insertionColor: NSColor(calibratedRed: 0.20, green: 0.36, blue: 0.92, alpha: 1),
            editorColor: NSColor(calibratedWhite: 1, alpha: 0.20),
            defaultFontNames: ["SF Pro", "SF Pro Display", "Helvetica Neue"],
            defaultFontSize: 21,
            lineSpacing: 8,
            typingProfile: .liquid,
            prefersPixelEdges: false
        )
    ]

    static func theme(_ id: ThemeID) -> WritingTheme {
        all.first(where: { $0.id == id }) ?? all[0]
    }
}
