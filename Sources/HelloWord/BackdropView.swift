import AppKit

enum EraCommand {
    case app
    case file
    case edit
    case format
    case world
    case sound
    case search
    case help
    case start
    case minimize
    case zoom
    case close
    case save
    case hideControls
}

final class BackdropView: NSView {
    var theme: WritingTheme = .theme(.calm) {
        didSet {
            updateGlassLayers()
            if let window { window.invalidateCursorRects(for: self) }
            needsDisplay = true
        }
    }

    /// Zero is genuinely transparent. Higher values add Apple blur and a quiet tint,
    /// while always preserving a view of the real desktop and windows behind this one.
    var liquidGlassAmount: CGFloat = 1.0 {
        didSet {
            liquidGlassAmount = max(0, min(1, liquidGlassAmount))
            updateGlassLayers()
            needsDisplay = true
        }
    }

    var onMouseActivity: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onEraCommand: ((EraCommand, NSEvent) -> Void)?

    private let glassEffect = NSVisualEffectView()
    private let glassTint = NSView()
    private let glassReflection = LiquidGlassReflectionView()
    private var worldArtCache: [String: NSImage] = [:]
    private var tracking: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureGlassLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureGlassLayers()
    }

    private func configureGlassLayers() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        glassEffect.material = .underWindowBackground
        glassEffect.blendingMode = .behindWindow
        glassEffect.state = .active
        glassEffect.isEmphasized = false

        glassTint.wantsLayer = true
        glassTint.layer?.backgroundColor = NSColor.clear.cgColor

        addSubview(glassEffect)
        addSubview(glassTint)
        addSubview(glassReflection)
        updateGlassLayers()
    }

    override func layout() {
        super.layout()
        glassEffect.frame = bounds
        glassTint.frame = bounds
        glassReflection.frame = bounds
    }

    private func updateGlassLayers() {
        let isGlass = theme.id == .liquidGlass
        let amount = liquidGlassAmount
        glassEffect.isHidden = !isGlass || amount < 0.002
        glassTint.isHidden = !isGlass || amount < 0.002
        glassReflection.isHidden = !isGlass || amount < 0.002
        glassEffect.alphaValue = amount * 0.82
        glassTint.layer?.backgroundColor = NSColor(
            calibratedRed: 0.72,
            green: 0.84,
            blue: 0.96,
            alpha: amount * 0.12
        ).cgColor
        glassReflection.amount = amount
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseMoved(with event: NSEvent) {
        onMouseActivity?()
        super.mouseMoved(with: event)
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseActivity?()
        super.mouseEntered(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let command = eraCommand(at: point) {
            onEraCommand?(command, event)
            return
        }
        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }
        super.mouseDown(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        for rect in eraCommandRects().map(\.0) {
            addCursorRect(rect, cursor: .pointingHand)
        }
    }

    private func eraCommand(at point: NSPoint) -> EraCommand? {
        eraCommandRects().first(where: { $0.0.contains(point) })?.1
    }

    private func eraCommandRects() -> [(NSRect, EraCommand)] {
        switch theme.id {
        case .mac1999:
            let y = bounds.maxY - 28
            return [
                (NSRect(x: 7, y: y, width: 31, height: 28), .app),
                (NSRect(x: 39, y: y, width: 42, height: 28), .file),
                (NSRect(x: 81, y: y, width: 43, height: 28), .edit),
                (NSRect(x: 124, y: y, width: 64, height: 28), .format),
                (NSRect(x: 188, y: y, width: 57, height: 28), .world),
                (NSRect(x: 245, y: y, width: 63, height: 28), .sound)
            ]
        case .system95:
            let commandsY = bounds.maxY - 49
            let titleY = bounds.maxY - 28
            return [
                (NSRect(x: 8, y: commandsY, width: 42, height: 19), .file),
                (NSRect(x: 50, y: commandsY, width: 43, height: 19), .edit),
                (NSRect(x: 93, y: commandsY, width: 59, height: 19), .search),
                (NSRect(x: 152, y: commandsY, width: 48, height: 19), .help),
                (NSRect(x: 5, y: 4, width: 72, height: 24), .start),
                (NSRect(x: bounds.maxX - 64, y: titleY, width: 22, height: 20), .minimize),
                (NSRect(x: bounds.maxX - 42, y: titleY, width: 20, height: 20), .zoom),
                (NSRect(x: bounds.maxX - 22, y: titleY, width: 18, height: 20), .close)
            ]
        case .dos:
            return [
                (NSRect(x: 20, y: 8, width: 75, height: 25), .help),
                (NSRect(x: 95, y: 8, width: 72, height: 25), .save),
                (NSRect(x: 167, y: 8, width: 87, height: 25), .world),
                (NSRect(x: 254, y: 8, width: 145, height: 25), .hideControls)
            ]
        default:
            return []
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill(using: .copy)

        switch theme.id {
        case .calm: drawCalm()
        case .mac1999: drawMac1999()
        case .system95: drawSystem95()
        case .dos: drawDOS()
        case .typewriter: drawTypewriter()
        case .library: drawLibrary()
        case .spaceAge: drawSpaceAge()
        case .cyberdeck: drawCyberdeck()
        case .hell: drawHell()
        case .liquidGlass: drawLiquidGlass()
        }
    }

    // MARK: - Complete writing worlds

    private func drawCalm() {
        if drawWorldArt(named: "Still") { return }
        let night = NSColor(calibratedRed: 0.16, green: 0.23, blue: 0.27, alpha: 1)
        let dawn = NSColor(calibratedRed: 0.73, green: 0.62, blue: 0.48, alpha: 1)
        let paperLight = NSColor(calibratedRed: 0.93, green: 0.84, blue: 0.68, alpha: 1)
        NSGradient(colorsAndLocations: (night, 0), (dawn, 0.48), (paperLight, 1))?.draw(in: bounds, angle: -90)

        // A whole quiet horizon, with the centre kept naturally readable rather than boxed.
        NSColor(calibratedRed: 1, green: 0.88, blue: 0.58, alpha: 0.24).setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 250, y: bounds.height * 0.42, width: 500, height: 500)).fill()
        for (index, alpha) in [0.12, 0.08, 0.05].enumerated() {
            NSColor(calibratedWhite: 1, alpha: alpha).setFill()
            let inset = CGFloat(index) * 90
            NSBezierPath(ovalIn: NSRect(x: bounds.midX - 410 - inset, y: bounds.height * 0.12 - inset * 0.2, width: 820 + inset * 2, height: 540 + inset)).fill()
        }

        NSColor(calibratedRed: 0.54, green: 0.56, blue: 0.47, alpha: 0.46).setFill()
        let hills = NSBezierPath()
        hills.move(to: NSPoint(x: 0, y: 0))
        hills.line(to: NSPoint(x: 0, y: bounds.height * 0.26))
        hills.curve(to: NSPoint(x: bounds.width * 0.54, y: bounds.height * 0.17), controlPoint1: NSPoint(x: bounds.width * 0.20, y: bounds.height * 0.40), controlPoint2: NSPoint(x: bounds.width * 0.35, y: bounds.height * 0.08))
        hills.curve(to: NSPoint(x: bounds.width, y: bounds.height * 0.30), controlPoint1: NSPoint(x: bounds.width * 0.72, y: bounds.height * 0.30), controlPoint2: NSPoint(x: bounds.width * 0.86, y: bounds.height * 0.18))
        hills.line(to: NSPoint(x: bounds.width, y: 0))
        hills.close()
        hills.fill()

        drawFineGrain(color: NSColor(calibratedWhite: 1, alpha: 0.035), spacing: 9)
    }

    private func drawMac1999() {
        NSColor(calibratedWhite: 0.88, alpha: 1).setFill()
        bounds.fill()
        drawPinstripes(in: bounds, light: 0.92, dark: 0.82, step: 4)

        let menu = NSRect(x: 0, y: bounds.maxY - 28, width: bounds.width, height: 28)
        NSColor(calibratedWhite: 0.94, alpha: 1).setFill(); menu.fill()
        drawBevel(menu, light: .white, dark: NSColor(calibratedWhite: 0.36, alpha: 1), width: 1)
        drawLabel("◈   File   Edit   Format   World   Sound", at: NSPoint(x: 12, y: bounds.maxY - 20), color: .black, size: 12, mono: false, weight: .medium)
        drawLabel("Hello, Word", at: NSPoint(x: max(20, bounds.midX - 40), y: bounds.maxY - 20), color: NSColor(calibratedWhite: 0.18, alpha: 1), size: 12, mono: false, weight: .semibold)

        // The classic document is maximised: the interface itself is the world.
        let title = NSRect(x: 6, y: bounds.maxY - 55, width: bounds.width - 12, height: 22)
        NSColor(calibratedRed: 0.33, green: 0.34, blue: 0.47, alpha: 1).setFill(); title.fill()
        for x in stride(from: title.minX + 34, to: title.maxX - 34, by: 4) {
            NSColor(calibratedWhite: 1, alpha: 0.32).setFill()
            NSRect(x: x, y: title.midY, width: 2, height: 1).fill()
        }
        drawLabel("UNTITLED — WRITE", at: NSPoint(x: title.midX - 48, y: title.minY + 5), color: .white, size: 10, mono: true, weight: .bold)
        drawClassicBox(NSRect(x: 10, y: 32, width: bounds.width - 20, height: bounds.height - 91), fill: NSColor(calibratedWhite: 0.965, alpha: 1))

        NSColor(calibratedWhite: 0.72, alpha: 1).setFill()
        NSRect(x: bounds.maxX - 25, y: 37, width: 11, height: bounds.height - 101).fill()
        drawBevel(NSRect(x: bounds.maxX - 25, y: bounds.height * 0.42, width: 11, height: 72), light: .white, dark: .darkGray, width: 1)
        drawLabel("words live here", at: NSPoint(x: 15, y: 12), color: NSColor(calibratedWhite: 0.32, alpha: 1), size: 10, mono: true, weight: .regular)
    }

    private func drawSystem95() {
        NSColor(calibratedRed: 0.00, green: 0.43, blue: 0.43, alpha: 1).setFill()
        bounds.fill()

        // A maximised, period-correct writing window instead of a floating white card.
        let frame = NSRect(x: 4, y: 34, width: bounds.width - 8, height: bounds.height - 38)
        NSColor(calibratedWhite: 0.76, alpha: 1).setFill(); frame.fill()
        drawBevel(frame, light: .white, dark: NSColor(calibratedWhite: 0.18, alpha: 1), width: 2)
        let title = NSRect(x: 8, y: bounds.maxY - 28, width: bounds.width - 16, height: 20)
        NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.52, alpha: 1).setFill(); title.fill()
        drawLabel("▣  HELLO, WORD — WRITE", at: NSPoint(x: 13, y: bounds.maxY - 23), color: .white, size: 11, mono: false, weight: .bold)
        drawLabel("_  □  ×", at: NSPoint(x: bounds.maxX - 58, y: bounds.maxY - 23), color: .white, size: 11, mono: true, weight: .bold)

        let commands = NSRect(x: 8, y: bounds.maxY - 49, width: bounds.width - 16, height: 19)
        NSColor(calibratedWhite: 0.76, alpha: 1).setFill(); commands.fill()
        drawLabel("File   Edit   Search   Help", at: NSPoint(x: 14, y: commands.minY + 4), color: .black, size: 11, mono: false, weight: .regular)
        NSColor.white.setFill()
        NSRect(x: 10, y: 40, width: bounds.width - 20, height: bounds.height - 91).fill()

        let taskbar = NSRect(x: 0, y: 0, width: bounds.width, height: 32)
        NSColor(calibratedWhite: 0.75, alpha: 1).setFill(); taskbar.fill()
        drawBevel(taskbar, light: .white, dark: NSColor(calibratedWhite: 0.28, alpha: 1), width: 2)
        drawClassicBox(NSRect(x: 5, y: 4, width: 72, height: 24), fill: NSColor(calibratedWhite: 0.76, alpha: 1))
        drawLabel("▤ Start", at: NSPoint(x: 12, y: 10), color: .black, size: 11, mono: false, weight: .bold)
        drawLabel("9:95 PM", at: NSPoint(x: bounds.maxX - 62, y: 10), color: .black, size: 10, mono: false, weight: .regular)
    }

    private func drawDOS() {
        NSColor(calibratedRed: 0.003, green: 0.010, blue: 0.020, alpha: 1).setFill()
        bounds.fill()

        NSColor(calibratedRed: 0.14, green: 0.82, blue: 0.38, alpha: 0.032).setFill()
        for y in stride(from: CGFloat(0), to: bounds.height, by: 3) {
            NSRect(x: 0, y: y, width: bounds.width, height: 1).fill()
        }
        NSColor(calibratedRed: 0.18, green: 0.95, blue: 0.45, alpha: 0.16).setStroke()
        let inner = bounds.insetBy(dx: 11, dy: 11)
        let border = NSBezierPath(rect: inner); border.lineWidth = 1; border.stroke()

        let green = NSColor(calibratedRed: 0.34, green: 0.95, blue: 0.56, alpha: 0.74)
        drawLabel("HELLO.WORD / MORAD", at: NSPoint(x: 24, y: bounds.maxY - 30), color: green, size: 11, mono: true, weight: .medium)
        drawLabel("F1 HELP   F2 SAVE   F3 WORLD   ESC HIDE CONTROLS", at: NSPoint(x: 24, y: 18), color: green.withAlphaComponent(0.55), size: 10, mono: true, weight: .regular)
        drawLabel("READY", at: NSPoint(x: bounds.maxX - 62, y: 18), color: green, size: 10, mono: true, weight: .bold)

        // CRT bloom, spread across the terminal rather than confined to a page.
        NSGradient(colors: [NSColor(calibratedRed: 0.10, green: 0.60, blue: 0.28, alpha: 0.075), .clear])?.draw(in: bounds.insetBy(dx: bounds.width * 0.12, dy: bounds.height * 0.08), relativeCenterPosition: .zero)
    }

    private func drawTypewriter() {
        if drawWorldArt(named: "Typewriter") { return }
        // A late-afternoon room: old plaster, an open shutter and a desk that has
        // survived more manuscripts than its owner remembers.
        NSGradient(colors: [
            NSColor(calibratedRed: 0.16, green: 0.105, blue: 0.060, alpha: 1),
            NSColor(calibratedRed: 0.47, green: 0.34, blue: 0.20, alpha: 1),
            NSColor(calibratedRed: 0.11, green: 0.070, blue: 0.045, alpha: 1)
        ])?.draw(in: bounds, angle: 0)
        drawFineGrain(color: NSColor(calibratedRed: 0.95, green: 0.79, blue: 0.51, alpha: 0.026), spacing: 13)

        let window = NSRect(x: 18, y: bounds.height * 0.43, width: max(112, bounds.width * 0.17), height: bounds.height * 0.47)
        NSGradient(colors: [
            NSColor(calibratedRed: 0.44, green: 0.67, blue: 0.71, alpha: 1),
            NSColor(calibratedRed: 0.74, green: 0.82, blue: 0.70, alpha: 1)
        ])?.draw(in: window, angle: -90)
        NSColor(calibratedRed: 0.08, green: 0.24, blue: 0.18, alpha: 0.54).setFill()
        let distantGreen = NSBezierPath()
        distantGreen.move(to: NSPoint(x: window.minX, y: window.minY))
        distantGreen.curve(to: NSPoint(x: window.maxX, y: window.minY + 34), controlPoint1: NSPoint(x: window.minX + 31, y: window.minY + 72), controlPoint2: NSPoint(x: window.maxX - 43, y: window.minY + 8))
        distantGreen.line(to: NSPoint(x: window.maxX, y: window.minY))
        distantGreen.close()
        distantGreen.fill()
        NSColor(calibratedRed: 0.10, green: 0.070, blue: 0.035, alpha: 0.92).setStroke()
        let windowFrame = NSBezierPath(rect: window.insetBy(dx: -7, dy: -7)); windowFrame.lineWidth = 13; windowFrame.stroke()
        for shutterX in [window.minX - 27, window.maxX + 7] {
            NSColor(calibratedRed: 0.13, green: 0.20, blue: 0.13, alpha: 1).setFill()
            let shutter = NSRect(x: shutterX, y: window.minY - 4, width: 21, height: window.height + 8)
            shutter.fill()
            NSColor(calibratedWhite: 0, alpha: 0.30).setFill()
            for y in stride(from: shutter.minY + 12, to: shutter.maxY - 6, by: 17) { NSRect(x: shutter.minX + 3, y: y, width: shutter.width - 6, height: 2).fill() }
        }

        let desk = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height * 0.30)
        NSGradient(colors: [
            NSColor(calibratedRed: 0.095, green: 0.045, blue: 0.022, alpha: 1),
            NSColor(calibratedRed: 0.35, green: 0.15, blue: 0.055, alpha: 1),
            NSColor(calibratedRed: 0.12, green: 0.055, blue: 0.025, alpha: 1)
        ])?.draw(in: desk, angle: 0)
        NSColor(calibratedWhite: 0, alpha: 0.16).setStroke()
        for index in 0..<9 {
            let grain = NSBezierPath()
            let y = desk.minY + CGFloat(9 + index * 17)
            grain.move(to: NSPoint(x: 0, y: y))
            grain.curve(to: NSPoint(x: bounds.maxX, y: y + CGFloat((index % 3) * 4 - 4)), controlPoint1: NSPoint(x: bounds.width * 0.28, y: y + 9), controlPoint2: NSPoint(x: bounds.width * 0.69, y: y - 7))
            grain.lineWidth = 1
            grain.stroke()
        }

        let pageLeft = max(76, bounds.width * 0.115)
        let pageRight = bounds.maxX - max(54, bounds.width * 0.085)
        let pageBottom = max(62, bounds.height * 0.105)
        let pageTop = bounds.maxY - 17
        func pagePath(dx: CGFloat = 0, dy: CGFloat = 0) -> NSBezierPath {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: pageLeft + 7 + dx, y: pageBottom + dy))
            path.curve(to: NSPoint(x: pageRight - 13 + dx, y: pageBottom + 2 + dy), controlPoint1: NSPoint(x: pageLeft + bounds.width * 0.22 + dx, y: pageBottom - 5 + dy), controlPoint2: NSPoint(x: pageRight - bounds.width * 0.20 + dx, y: pageBottom + 8 + dy))
            path.curve(to: NSPoint(x: pageRight + dx, y: pageTop - 14 + dy), controlPoint1: NSPoint(x: pageRight - 5 + dx, y: pageBottom + bounds.height * 0.27 + dy), controlPoint2: NSPoint(x: pageRight + 5 + dx, y: pageTop - bounds.height * 0.24 + dy))
            path.curve(to: NSPoint(x: pageLeft + 3 + dx, y: pageTop + dy), controlPoint1: NSPoint(x: pageRight - bounds.width * 0.24 + dx, y: pageTop + 5 + dy), controlPoint2: NSPoint(x: pageLeft + bounds.width * 0.23 + dx, y: pageTop - 5 + dy))
            path.curve(to: NSPoint(x: pageLeft + 7 + dx, y: pageBottom + dy), controlPoint1: NSPoint(x: pageLeft - 3 + dx, y: pageTop - bounds.height * 0.24 + dy), controlPoint2: NSPoint(x: pageLeft + 2 + dx, y: pageBottom + bounds.height * 0.25 + dy))
            path.close()
            return path
        }

        NSColor(calibratedWhite: 0, alpha: 0.34).setFill()
        pagePath(dx: 12, dy: -10).fill()
        let page = pagePath()
        NSGradient(colors: [
            NSColor(calibratedRed: 0.84, green: 0.76, blue: 0.60, alpha: 1),
            NSColor(calibratedRed: 0.985, green: 0.955, blue: 0.84, alpha: 1),
            NSColor(calibratedRed: 0.91, green: 0.85, blue: 0.70, alpha: 1)
        ])?.draw(in: page, angle: 0)
        NSColor(calibratedRed: 0.23, green: 0.15, blue: 0.075, alpha: 0.38).setStroke()
        page.lineWidth = 0.9
        page.stroke()

        NSGraphicsContext.saveGraphicsState()
        page.addClip()
        drawFineGrain(in: NSRect(x: pageLeft, y: pageBottom, width: pageRight - pageLeft, height: pageTop - pageBottom), color: NSColor(calibratedRed: 0.28, green: 0.20, blue: 0.11, alpha: 0.038), spacing: 12)
        NSColor(calibratedRed: 0.31, green: 0.20, blue: 0.10, alpha: 0.10).setStroke()
        let crease = NSBezierPath()
        crease.move(to: NSPoint(x: pageLeft + 18, y: pageTop - 53))
        crease.curve(to: NSPoint(x: pageRight - 21, y: pageTop - 47), controlPoint1: NSPoint(x: bounds.midX - 110, y: pageTop - 46), controlPoint2: NSPoint(x: bounds.midX + 100, y: pageTop - 58))
        crease.lineWidth = 0.6
        crease.stroke()
        NSGraphicsContext.restoreGraphicsState()

        // The machine occupies the foreground without turning the page into a box.
        let platen = NSRect(x: pageLeft - 24, y: pageBottom - 8, width: pageRight - pageLeft + 48, height: 27)
        NSGradient(colors: [NSColor(calibratedWhite: 0.025, alpha: 1), NSColor(calibratedWhite: 0.20, alpha: 1), NSColor(calibratedWhite: 0.035, alpha: 1)])?.draw(in: platen, angle: -90)
        NSColor(calibratedWhite: 0.72, alpha: 0.55).setFill()
        for x in stride(from: platen.minX + 17, to: platen.maxX - 10, by: 22) { NSRect(x: x, y: platen.minY + 3, width: 1, height: 5).fill() }

        let machine = NSBezierPath()
        machine.move(to: NSPoint(x: bounds.width * 0.16, y: 0))
        machine.line(to: NSPoint(x: bounds.width * 0.20, y: 58))
        machine.curve(to: NSPoint(x: bounds.width * 0.80, y: 58), controlPoint1: NSPoint(x: bounds.width * 0.35, y: 74), controlPoint2: NSPoint(x: bounds.width * 0.65, y: 74))
        machine.line(to: NSPoint(x: bounds.width * 0.84, y: 0))
        machine.close()
        NSGradient(colors: [NSColor(calibratedRed: 0.025, green: 0.030, blue: 0.027, alpha: 1), NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.105, alpha: 1)])?.draw(in: machine, angle: -90)
        NSColor(calibratedWhite: 0.76, alpha: 0.32).setFill()
        for index in 0..<13 {
            let keyX = bounds.width * 0.28 + CGFloat(index) * bounds.width * 0.035
            NSBezierPath(ovalIn: NSRect(x: keyX, y: 15 + CGFloat(index % 2) * 8, width: 15, height: 10)).fill()
        }

        drawLabel("A room. A machine. The next sentence.", at: NSPoint(x: bounds.maxX - 245, y: 17), color: NSColor(calibratedRed: 0.93, green: 0.77, blue: 0.48, alpha: 0.54), size: 10, mono: false, weight: .medium)
    }

    private func drawLibrary() {
        if drawWorldArt(named: "Midnight Library") {
            // The room remains recognisable at the perimeter, while a quiet ivory
            // atmosphere keeps shelves and furniture from competing with prose.
            NSColor(calibratedRed: 1, green: 0.965, blue: 0.88, alpha: 0.11).setFill()
            bounds.fill()
            let writingAir = NSRect(
                x: bounds.width * 0.18,
                y: bounds.height * 0.055,
                width: bounds.width * 0.64,
                height: bounds.height * 0.89
            )
            NSGradient(colors: [
                NSColor(calibratedRed: 1, green: 0.975, blue: 0.91, alpha: 0.20),
                NSColor(calibratedRed: 1, green: 0.96, blue: 0.86, alpha: 0.085)
            ])?.draw(in: writingAir, relativeCenterPosition: .zero)
            return
        }
        let blackGreen = NSColor(calibratedRed: 0.008, green: 0.025, blue: 0.021, alpha: 1)
        let warmWood = NSColor(calibratedRed: 0.15, green: 0.072, blue: 0.035, alpha: 1)
        NSGradient(colors: [blackGreen, warmWood, blackGreen])?.draw(in: bounds, angle: 0)

        drawBookshelf(in: NSRect(x: 0, y: 0, width: bounds.width * 0.22, height: bounds.height))
        drawBookshelf(in: NSRect(x: bounds.width * 0.78, y: 0, width: bounds.width * 0.22, height: bounds.height))

        // Rainy leaded window behind the writing air.
        let window = NSRect(x: bounds.width * 0.26, y: bounds.height * 0.52, width: bounds.width * 0.48, height: bounds.height * 0.42)
        NSGradient(colors: [NSColor(calibratedRed: 0.025, green: 0.085, blue: 0.10, alpha: 1), NSColor(calibratedRed: 0.10, green: 0.15, blue: 0.16, alpha: 1)])?.draw(in: window, angle: -90)
        NSColor(calibratedWhite: 0.55, alpha: 0.12).setStroke()
        let panes = NSBezierPath()
        panes.move(to: NSPoint(x: window.midX, y: window.minY)); panes.line(to: NSPoint(x: window.midX, y: window.maxY))
        panes.move(to: NSPoint(x: window.minX, y: window.midY)); panes.line(to: NSPoint(x: window.maxX, y: window.midY))
        panes.stroke()
        NSColor(calibratedRed: 0.58, green: 0.72, blue: 0.75, alpha: 0.17).setStroke()
        for x in stride(from: window.minX + 15, to: window.maxX, by: 31) {
            let rain = NSBezierPath(); rain.move(to: NSPoint(x: x, y: window.minY + 12)); rain.line(to: NSPoint(x: x + 8, y: window.maxY - 9)); rain.lineWidth = 1; rain.stroke()
        }

        let lampGlow = NSRect(x: bounds.midX - 400, y: bounds.height * 0.05, width: 800, height: bounds.height * 0.76)
        NSGradient(colors: [NSColor(calibratedRed: 0.94, green: 0.69, blue: 0.30, alpha: 0.22), .clear])?.draw(in: lampGlow, relativeCenterPosition: NSPoint(x: 0, y: -0.35))
        NSColor(calibratedRed: 0.05, green: 0.15, blue: 0.10, alpha: 1).setFill()
        let shade = NSBezierPath()
        shade.move(to: NSPoint(x: bounds.midX - 84, y: bounds.maxY - 58)); shade.line(to: NSPoint(x: bounds.midX + 84, y: bounds.maxY - 58)); shade.line(to: NSPoint(x: bounds.midX + 48, y: bounds.maxY - 126)); shade.line(to: NSPoint(x: bounds.midX - 48, y: bounds.maxY - 126)); shade.close(); shade.fill()
    }

    private func drawSpaceAge() {
        let deep = NSColor(calibratedRed: 0.015, green: 0.04, blue: 0.075, alpha: 1)
        let blue = NSColor(calibratedRed: 0.035, green: 0.16, blue: 0.20, alpha: 1)
        NSGradient(colors: [deep, blue, deep])?.draw(in: bounds, angle: 0)

        // A panoramic orbital window, with a curved planet horizon below.
        let viewport = bounds.insetBy(dx: 44, dy: 44)
        NSColor(calibratedWhite: 0.7, alpha: 0.11).setStroke()
        let rim = NSBezierPath(roundedRect: viewport, xRadius: 80, yRadius: 80); rim.lineWidth = 4; rim.stroke()
        let starColor = NSColor(calibratedRed: 0.90, green: 0.95, blue: 1, alpha: 0.70)
        starColor.setFill()
        for index in 0..<72 {
            let x = viewport.minX + CGFloat((index * 83) % max(1, Int(viewport.width - 20))) + 10
            let y = viewport.minY + CGFloat((index * 47 + index * index * 3) % max(1, Int(viewport.height - 30))) + 15
            let size: CGFloat = index % 9 == 0 ? 2.2 : 1.1
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: size, height: size)).fill()
        }
        let planet = NSRect(x: -bounds.width * 0.12, y: -bounds.height * 0.82, width: bounds.width * 1.24, height: bounds.height * 1.12)
        NSColor(calibratedRed: 0.91, green: 0.30, blue: 0.10, alpha: 0.96).setFill(); NSBezierPath(ovalIn: planet).fill()
        NSColor(calibratedRed: 1, green: 0.77, blue: 0.28, alpha: 0.46).setStroke()
        let atmosphere = NSBezierPath(ovalIn: planet.insetBy(dx: -7, dy: -7)); atmosphere.lineWidth = 5; atmosphere.stroke()
        NSColor(calibratedRed: 0.94, green: 0.78, blue: 0.46, alpha: 0.12).setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 520, y: bounds.midY - 330, width: 1040, height: 660)).fill()

        let console = NSRect(x: 0, y: 0, width: bounds.width, height: 40)
        NSColor(calibratedRed: 0.83, green: 0.76, blue: 0.57, alpha: 1).setFill(); console.fill()
        for x in stride(from: CGFloat(24), to: bounds.width, by: 58) {
            NSColor(calibratedRed: 0.93, green: 0.26, blue: 0.10, alpha: 0.9).setFill(); NSBezierPath(ovalIn: NSRect(x: x, y: 15, width: 8, height: 8)).fill()
        }
        drawLabel("ORBITAL WORD DECK  /  1968", at: NSPoint(x: bounds.midX - 90, y: 14), color: NSColor(calibratedRed: 0.12, green: 0.18, blue: 0.18, alpha: 1), size: 10, mono: true, weight: .bold)
    }

    private func drawCyberdeck() {
        let blackBlue = NSColor(calibratedRed: 0.003, green: 0.010, blue: 0.035, alpha: 1)
        let night = NSColor(calibratedRed: 0.010, green: 0.035, blue: 0.085, alpha: 1)
        NSGradient(colors: [blackBlue, night, blackBlue])?.draw(in: bounds, angle: 0)

        let cyan = NSColor(calibratedRed: 0.10, green: 0.94, blue: 1, alpha: 0.72)
        let magenta = NSColor(calibratedRed: 1, green: 0.06, blue: 0.62, alpha: 0.72)

        // A distant rain-black skyline gives the deck a world beyond the screen.
        NSColor(calibratedRed: 0.015, green: 0.025, blue: 0.055, alpha: 1).setFill()
        var x: CGFloat = 0
        var building = 0
        while x < bounds.maxX {
            let width = CGFloat(34 + (building * 19) % 58)
            let height = bounds.height * CGFloat(0.19 + Double((building * 23) % 28) / 100)
            NSRect(x: x, y: bounds.height * 0.22, width: width, height: height).fill()
            let light = building % 2 == 0 ? cyan : magenta
            light.withAlphaComponent(0.18).setFill()
            for wy in stride(from: bounds.height * 0.25, to: bounds.height * 0.22 + height - 8, by: 17) {
                NSRect(x: x + 8 + CGFloat((building * 7) % 11), y: wy, width: 2, height: 5).fill()
            }
            x += width + 5
            building += 1
        }

        // Neon perspective grid is held to the lower deck, away from the text.
        cyan.withAlphaComponent(0.13).setStroke()
        for rayX in stride(from: -bounds.width, to: bounds.width * 2, by: 70) {
            let ray = NSBezierPath(); ray.move(to: NSPoint(x: bounds.midX, y: bounds.height * 0.24)); ray.line(to: NSPoint(x: rayX, y: 0)); ray.lineWidth = 1; ray.stroke()
        }
        for gridY in stride(from: CGFloat(0), to: bounds.height * 0.24, by: 31) {
            NSRect(x: 0, y: gridY, width: bounds.width, height: 1).fill()
        }

        // The central data-black field is edge-free and deliberately quiet.
        let focus = NSBezierPath(ovalIn: NSRect(x: bounds.width * 0.09, y: -bounds.height * 0.10, width: bounds.width * 0.82, height: bounds.height * 1.22))
        NSColor(calibratedRed: 0.002, green: 0.012, blue: 0.035, alpha: 0.82).setFill()
        focus.fill()

        // Side-channel instrumentation: useful atmosphere without debris behind prose.
        for side in [CGFloat(0), CGFloat(1)] {
            let left = side == 0
            let panelX = left ? 15 : bounds.maxX - 115
            let panel = NSRect(x: panelX, y: bounds.height * 0.38, width: 100, height: bounds.height * 0.48)
            NSColor(calibratedRed: 0.008, green: 0.035, blue: 0.070, alpha: 0.82).setFill()
            NSBezierPath(roundedRect: panel, xRadius: 4, yRadius: 4).fill()
            (left ? cyan : magenta).setStroke()
            let border = NSBezierPath(roundedRect: panel, xRadius: 4, yRadius: 4); border.lineWidth = 1.5; border.stroke()
            for row in 0..<8 {
                let width = CGFloat(22 + (row * 17) % 58)
                (row % 3 == 0 ? magenta : cyan).withAlphaComponent(0.46).setFill()
                let lineX = left ? panel.minX + 12 : panel.maxX - 12 - width
                NSRect(x: lineX, y: panel.maxY - 25 - CGFloat(row * 24), width: width, height: row % 3 == 0 ? 3 : 1).fill()
            }
        }

        // Rain is visible only in the outer city channels.
        for index in 0..<34 {
            let left = index % 2 == 0
            let rainX = left
                ? CGFloat((index * 47) % max(1, Int(bounds.width * 0.15)))
                : bounds.maxX - CGFloat((index * 53) % max(1, Int(bounds.width * 0.15)))
            let rainY = CGFloat((index * 79) % max(1, Int(bounds.height)))
            cyan.withAlphaComponent(0.15).setStroke()
            let drop = NSBezierPath(); drop.move(to: NSPoint(x: rainX, y: rainY)); drop.line(to: NSPoint(x: rainX + 6, y: rainY + 21)); drop.stroke()
        }

        drawLabel("CYBERDECK 2088  //  NIGHT LINK STABLE", at: NSPoint(x: 18, y: bounds.maxY - 28), color: cyan.withAlphaComponent(0.58), size: 10, mono: true, weight: .bold)
        drawLabel("WRITE / ENCRYPT / DISAPPEAR", at: NSPoint(x: bounds.maxX - 177, y: 14), color: magenta.withAlphaComponent(0.52), size: 9, mono: true, weight: .medium)
    }

    private func drawHell() {
        if drawWorldArt(named: "Hell") { return }
        let void = NSColor(calibratedRed: 0.010, green: 0.004, blue: 0.006, alpha: 1)
        let blood = NSColor(calibratedRed: 0.22, green: 0.010, blue: 0.008, alpha: 1)
        let furnace = NSColor(calibratedRed: 0.72, green: 0.075, blue: 0.018, alpha: 1)
        NSGradient(colors: [blood, void, void, NSColor(calibratedRed: 0.12, green: 0.006, blue: 0.008, alpha: 1)])?.draw(in: bounds, angle: -90)

        let horizon = bounds.height * 0.27

        // A sulphurous sky, heavy enough to feel inhabited but kept behind the prose.
        for band in 0..<4 {
            let y = bounds.height * (0.56 + CGFloat(band) * 0.105)
            let cloud = NSBezierPath()
            cloud.move(to: NSPoint(x: 0, y: y))
            cloud.curve(
                to: NSPoint(x: bounds.maxX, y: y + CGFloat((band % 2) * 18 - 7)),
                controlPoint1: NSPoint(x: bounds.width * 0.24, y: y - 38 - CGFloat(band * 4)),
                controlPoint2: NSPoint(x: bounds.width * 0.72, y: y + 30 + CGFloat(band * 3))
            )
            cloud.line(to: NSPoint(x: bounds.maxX, y: y + 64))
            cloud.line(to: NSPoint(x: 0, y: y + 64))
            cloud.close()
            NSColor(calibratedRed: 0.20, green: 0.012, blue: 0.012, alpha: 0.10 + CGFloat(band) * 0.025).setFill()
            cloud.fill()
        }

        // The horizon is a wound of light behind Pandemonium, not a cheerful fire.
        NSGradient(colors: [
            NSColor(calibratedRed: 0.03, green: 0.004, blue: 0.006, alpha: 0),
            furnace.withAlphaComponent(0.46),
            NSColor(calibratedRed: 0.24, green: 0.010, blue: 0.006, alpha: 0.70),
            .clear
        ])?.draw(in: NSRect(x: 0, y: horizon - 54, width: bounds.width, height: 190), angle: -90)

        // The distant city of iron: spires, buttresses and one impossible gate.
        NSColor(calibratedRed: 0.020, green: 0.006, blue: 0.008, alpha: 0.98).setFill()
        for index in 0..<17 {
            let width = bounds.width / 17
            let x = CGFloat(index) * width - 4
            let towerHeight = CGFloat(34 + ((index * 47) % 86))
            let tower = NSBezierPath()
            tower.move(to: NSPoint(x: x, y: horizon - 15))
            tower.line(to: NSPoint(x: x + width * 0.18, y: horizon + towerHeight))
            tower.line(to: NSPoint(x: x + width * 0.36, y: horizon + towerHeight + CGFloat(20 + (index % 3) * 13)))
            tower.line(to: NSPoint(x: x + width * 0.54, y: horizon + towerHeight))
            tower.line(to: NSPoint(x: x + width * 0.82, y: horizon - 15))
            tower.close()
            tower.fill()
        }

        let gateOuter = NSBezierPath(roundedRect: NSRect(x: bounds.width * 0.39, y: horizon - 18, width: bounds.width * 0.22, height: bounds.height * 0.36), xRadius: bounds.width * 0.11, yRadius: bounds.width * 0.11)
        NSColor(calibratedRed: 0.030, green: 0.007, blue: 0.009, alpha: 1).setFill()
        gateOuter.fill()
        let gateMouth = NSBezierPath(roundedRect: NSRect(x: bounds.width * 0.435, y: horizon - 12, width: bounds.width * 0.13, height: bounds.height * 0.27), xRadius: bounds.width * 0.065, yRadius: bounds.width * 0.065)
        NSGradient(colors: [NSColor.black, blood, furnace.withAlphaComponent(0.64)])?.draw(in: gateMouth, angle: -90)
        NSColor(calibratedRed: 0.58, green: 0.055, blue: 0.025, alpha: 0.55).setStroke()
        gateMouth.lineWidth = 2.3
        gateMouth.stroke()

        // A basalt causeway draws the room toward the gate.
        let causeway = NSBezierPath()
        causeway.move(to: NSPoint(x: bounds.width * 0.46, y: horizon))
        causeway.line(to: NSPoint(x: bounds.width * 0.54, y: horizon))
        causeway.line(to: NSPoint(x: bounds.width * 0.73, y: 0))
        causeway.line(to: NSPoint(x: bounds.width * 0.27, y: 0))
        causeway.close()
        NSGradient(colors: [NSColor(calibratedWhite: 0.005, alpha: 1), NSColor(calibratedRed: 0.10, green: 0.010, blue: 0.010, alpha: 1)])?.draw(in: causeway, angle: 90)
        NSColor(calibratedRed: 0.48, green: 0.030, blue: 0.015, alpha: 0.40).setStroke()
        for index in 0..<7 {
            let t = CGFloat(index + 1) / 8
            let y = horizon * (1 - t * t)
            let halfWidth = bounds.width * (0.04 + 0.19 * t)
            let seam = NSBezierPath()
            seam.move(to: NSPoint(x: bounds.midX - halfWidth, y: y))
            seam.line(to: NSPoint(x: bounds.midX + halfWidth, y: y))
            seam.lineWidth = index < 3 ? 0.8 : 1.4
            seam.stroke()
        }
        for offset in [-0.20, -0.11, 0.11, 0.20] as [CGFloat] {
            let crack = NSBezierPath()
            crack.move(to: NSPoint(x: bounds.midX, y: horizon))
            crack.line(to: NSPoint(x: bounds.midX + bounds.width * offset, y: 0))
            crack.lineWidth = 1
            crack.stroke()
        }

        // Monumental columns and hanging iron turn the edges into a fallen cathedral.
        for side in [CGFloat(0), CGFloat(1)] {
            let left = side == 0
            let gate = NSRect(x: left ? -22 : bounds.maxX - bounds.width * 0.16 + 22, y: 0, width: bounds.width * 0.16, height: bounds.height)
            NSGradient(colors: [
                NSColor(calibratedWhite: 0.008, alpha: 1),
                NSColor(calibratedRed: 0.13, green: 0.015, blue: 0.014, alpha: 1),
                NSColor(calibratedWhite: 0.004, alpha: 1)
            ])?.draw(in: gate, angle: left ? 0 : 180)
            NSColor(calibratedRed: 0.62, green: 0.050, blue: 0.022, alpha: 0.34).setStroke()
            for rib in stride(from: gate.minX + 25, to: gate.maxX, by: 32) {
                let line = NSBezierPath()
                line.move(to: NSPoint(x: rib, y: 0))
                line.curve(to: NSPoint(x: rib + (left ? 14 : -14), y: gate.maxY), controlPoint1: NSPoint(x: rib - 9, y: gate.height * 0.34), controlPoint2: NSPoint(x: rib + 18, y: gate.height * 0.73))
                line.lineWidth = 2.2
                line.stroke()
            }
            let chainX = left ? gate.maxX - 17 : gate.minX + 17
            for y in stride(from: CGFloat(22), to: bounds.maxY - 12, by: 29) {
                let link = NSBezierPath(ovalIn: NSRect(x: chainX - 7, y: y, width: 14, height: 22))
                link.lineWidth = 2.4
                NSColor(calibratedRed: 0.38, green: 0.060, blue: 0.040, alpha: 0.62).setStroke()
                link.stroke()
            }
        }

        // A restrained central veil protects legibility without erasing the world.
        let veil = NSBezierPath(ovalIn: NSRect(x: bounds.width * 0.13, y: bounds.height * 0.20, width: bounds.width * 0.74, height: bounds.height * 0.90))
        NSColor(calibratedWhite: 0, alpha: 0.30).setFill()
        veil.fill()

        // Embers climb the peripheral air like slow ash.
        for index in 0..<34 {
            let left = index % 2 == 0
            let x = left ? CGFloat(12 + (index * 43) % max(24, Int(bounds.width * 0.18))) : bounds.maxX - CGFloat(12 + (index * 47) % max(24, Int(bounds.width * 0.18)))
            let y = CGFloat((index * 83 + 29) % max(1, Int(bounds.height - 38)))
            let size: CGFloat = index % 7 == 0 ? 3.0 : (index % 3 == 0 ? 1.8 : 1.0)
            furnace.withAlphaComponent(index % 5 == 0 ? 0.68 : 0.38).setFill()
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: size, height: size * 1.7)).fill()
        }

        drawLabel(
            "Hell  /  The deadline is eternal",
            at: NSPoint(x: 18, y: bounds.maxY - 29),
            color: NSColor(calibratedRed: 0.72, green: 0.13, blue: 0.07, alpha: 0.72),
            size: 10,
            mono: true,
            weight: .bold
        )
    }

    private func drawLiquidGlass() {
        guard liquidGlassAmount > 0.001 else { return }

        // Only transparent light is drawn here. There is deliberately no fake wallpaper.
        let amount = liquidGlassAmount
        NSGradient(colors: [
            NSColor(calibratedRed: 0.66, green: 0.82, blue: 1, alpha: amount * 0.075),
            NSColor(calibratedRed: 0.93, green: 0.75, blue: 1, alpha: amount * 0.045),
            NSColor(calibratedRed: 0.68, green: 1, blue: 0.90, alpha: amount * 0.055)
        ])?.draw(in: bounds, angle: -22)

        NSColor(calibratedWhite: 1, alpha: amount * 0.24).setStroke()
        let edge = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.75, dy: 0.75), xRadius: 24, yRadius: 24)
        edge.lineWidth = 1.5
        edge.stroke()
    }

    // MARK: - Drawing helpers

    @discardableResult
    private func drawWorldArt(named name: String) -> Bool {
        let image: NSImage
        if let cached = worldArtCache[name] {
            image = cached
        } else {
            guard let resourcesURL = Bundle.main.resourceURL else { return false }
            let url = resourcesURL
                .appendingPathComponent("World Art", isDirectory: true)
                .appendingPathComponent(name)
                .appendingPathExtension("png")
            guard FileManager.default.fileExists(atPath: url.path),
                  let loaded = NSImage(contentsOf: url), loaded.size.width > 0, loaded.size.height > 0 else { return false }
            worldArtCache[name] = loaded
            image = loaded
        }

        let sourceAspect = image.size.width / image.size.height
        let targetAspect = max(0.01, bounds.width / max(1, bounds.height))
        var source = NSRect(origin: .zero, size: image.size)
        if sourceAspect > targetAspect {
            let width = image.size.height * targetAspect
            source.origin.x = (image.size.width - width) * 0.5
            source.size.width = width
        } else {
            let height = image.size.width / targetAspect
            source.origin.y = (image.size.height - height) * 0.5
            source.size.height = height
        }
        image.draw(
            in: bounds,
            from: source,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        return true
    }

    private func drawPinstripes(in rect: NSRect, light: CGFloat, dark: CGFloat, step: CGFloat) {
        for y in stride(from: rect.minY, to: rect.maxY, by: step) {
            NSColor(calibratedWhite: light, alpha: 0.30).setFill(); NSRect(x: rect.minX, y: y, width: rect.width, height: 1).fill()
            NSColor(calibratedWhite: dark, alpha: 0.22).setFill(); NSRect(x: rect.minX, y: y + 1, width: rect.width, height: 1).fill()
        }
    }

    private func drawClassicBox(_ rect: NSRect, fill: NSColor) {
        fill.setFill(); rect.fill()
        drawBevel(rect, light: .white, dark: NSColor(calibratedWhite: 0.30, alpha: 1), width: 2)
    }

    private func drawBevel(_ rect: NSRect, light: NSColor, dark: NSColor, width: CGFloat) {
        light.setFill()
        NSRect(x: rect.minX, y: rect.maxY - width, width: rect.width, height: width).fill()
        NSRect(x: rect.minX, y: rect.minY, width: width, height: rect.height).fill()
        dark.setFill()
        NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: width).fill()
        NSRect(x: rect.maxX - width, y: rect.minY, width: width, height: rect.height).fill()
    }

    private func drawLabel(_ text: String, at point: NSPoint, color: NSColor, size: CGFloat, mono: Bool, weight: NSFont.Weight) {
        let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
        text.draw(at: point, withAttributes: [.font: font, .foregroundColor: color])
    }

    private func drawFineGrain(color: NSColor, spacing: CGFloat) {
        drawFineGrain(in: bounds, color: color, spacing: spacing)
    }

    private func drawFineGrain(in rect: NSRect, color: NSColor, spacing: CGFloat) {
        color.setFill()
        var index = 0
        for y in stride(from: rect.minY + 2, to: rect.maxY, by: spacing) {
            let offset = CGFloat((index * 17) % max(1, Int(spacing * 4)))
            for x in stride(from: rect.minX + offset, to: rect.maxX, by: spacing * 5) {
                NSRect(x: x, y: y, width: 1, height: 1).fill()
            }
            index += 1
        }
    }

    private func drawBookshelf(in rect: NSRect) {
        NSColor(calibratedRed: 0.10, green: 0.045, blue: 0.022, alpha: 1).setFill(); rect.fill()
        let shelfHeight: CGFloat = 94
        for shelfY in stride(from: rect.minY, to: rect.maxY, by: shelfHeight) {
            NSColor(calibratedRed: 0.30, green: 0.14, blue: 0.055, alpha: 1).setFill()
            NSRect(x: rect.minX, y: shelfY, width: rect.width, height: 8).fill()
            var x = rect.minX + 8
            var bookIndex = 0
            while x < rect.maxX - 6 {
                let width = CGFloat(9 + (bookIndex * 7) % 13)
                let height = CGFloat(50 + (bookIndex * 17) % 31)
                let colors = [
                    NSColor(calibratedRed: 0.34, green: 0.09, blue: 0.07, alpha: 1),
                    NSColor(calibratedRed: 0.08, green: 0.22, blue: 0.15, alpha: 1),
                    NSColor(calibratedRed: 0.25, green: 0.18, blue: 0.06, alpha: 1),
                    NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.24, alpha: 1)
                ]
                colors[bookIndex % colors.count].setFill()
                NSRect(x: x, y: shelfY + 8, width: width, height: min(height, shelfHeight - 12)).fill()
                x += width + 3
                bookIndex += 1
            }
        }
    }
}

/// Specular light that sits above the native behind-window material. It suggests
/// curved, reflective glass without replacing the real desktop with a fake image.
private final class LiquidGlassReflectionView: NSView {
    var amount: CGFloat = 1.0 {
        didSet { needsDisplay = true }
    }

    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard amount > 0.001 else { return }

        NSGraphicsContext.saveGraphicsState()

        // A broad window-like reflection crossing the upper glass.
        let sweep = NSBezierPath()
        sweep.move(to: NSPoint(x: bounds.minX - 90, y: bounds.maxY * 0.70))
        sweep.curve(
            to: NSPoint(x: bounds.maxX + 90, y: bounds.maxY * 0.91),
            controlPoint1: NSPoint(x: bounds.width * 0.20, y: bounds.maxY * 1.04),
            controlPoint2: NSPoint(x: bounds.width * 0.72, y: bounds.maxY * 0.60)
        )
        sweep.line(to: NSPoint(x: bounds.maxX + 90, y: bounds.maxY * 0.82))
        sweep.curve(
            to: NSPoint(x: bounds.minX - 90, y: bounds.maxY * 0.58),
            controlPoint1: NSPoint(x: bounds.width * 0.70, y: bounds.maxY * 0.53),
            controlPoint2: NSPoint(x: bounds.width * 0.19, y: bounds.maxY * 0.94)
        )
        sweep.close()
        NSColor(calibratedWhite: 1, alpha: amount * 0.070).setFill()
        sweep.fill()

        // Thin, bright edge glints with a faint prismatic partner.
        let glint = NSBezierPath()
        glint.move(to: NSPoint(x: bounds.width * 0.055, y: bounds.maxY - 16))
        glint.curve(
            to: NSPoint(x: bounds.width * 0.64, y: bounds.maxY - 9),
            controlPoint1: NSPoint(x: bounds.width * 0.20, y: bounds.maxY - 3),
            controlPoint2: NSPoint(x: bounds.width * 0.43, y: bounds.maxY - 25)
        )
        NSColor(calibratedWhite: 1, alpha: amount * 0.52).setStroke()
        glint.lineWidth = 1.3
        glint.stroke()

        let cyanEdge = NSBezierPath()
        cyanEdge.move(to: NSPoint(x: bounds.maxX - 7, y: bounds.height * 0.20))
        cyanEdge.curve(
            to: NSPoint(x: bounds.maxX - 12, y: bounds.height * 0.76),
            controlPoint1: NSPoint(x: bounds.maxX + 4, y: bounds.height * 0.39),
            controlPoint2: NSPoint(x: bounds.maxX - 22, y: bounds.height * 0.61)
        )
        NSColor(calibratedRed: 0.35, green: 0.92, blue: 1, alpha: amount * 0.30).setStroke()
        cyanEdge.lineWidth = 2
        cyanEdge.stroke()

        let pinkEdge = NSBezierPath()
        pinkEdge.move(to: NSPoint(x: 8, y: bounds.height * 0.18))
        pinkEdge.curve(
            to: NSPoint(x: 12, y: bounds.height * 0.58),
            controlPoint1: NSPoint(x: -3, y: bounds.height * 0.31),
            controlPoint2: NSPoint(x: 22, y: bounds.height * 0.47)
        )
        NSColor(calibratedRed: 1, green: 0.58, blue: 0.86, alpha: amount * 0.22).setStroke()
        pinkEdge.lineWidth = 1.6
        pinkEdge.stroke()

        NSGraphicsContext.restoreGraphicsState()
    }
}
