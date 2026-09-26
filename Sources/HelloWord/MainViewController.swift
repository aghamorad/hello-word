import AppKit
import CoreImage
import UniformTypeIdentifiers

final class MainViewController: NSViewController, NSTextViewDelegate, NSWindowDelegate {
    private let backdrop = BackdropView()
    private let scrollView = NSScrollView()
    let textView: FocusTextView

    private let hud = NSVisualEffectView()
    private let splash = NSVisualEffectView()
    private let themePopup = NSPopUpButton()
    private let correctionPopup = NSPopUpButton()
    private let typingButton = NSButton()
    private let musicButton = NSButton()
    private let folderButton = NSButton()
    private let fullScreenButton = NSButton()
    private let fontButton = NSButton()
    private let footnoteButton = NSButton()
    private let smallerButton = NSButton()
    private let largerButton = NSButton()
    private let writingWidthSlider = NSSlider()
    private let glassTintSlider = NSSlider()
    private let widthControl = NSStackView()
    private let glassControl = NSStackView()
    private let countLabel = NSTextField(labelWithString: "0 words")
    private let updateStamp = NSButton()
    private let updates = UpdateChecker()
    private var stampColor: NSColor = .secondaryLabelColor
    private var hasCheckedForUpdates = false

    private let typingAudio = TypingAudioController()
    private let musicLibrary = MusicLibrary()
    private let correctionEngine = LocalCorrectionEngine()
    private let harper = HarperCorrectionService()

    private var currentTheme: WritingTheme = .theme(.calm)
    private var currentURL: URL?
    private var isDirty = false
    private var autosaveWork: DispatchWorkItem?
    private var hideHUDWork: DispatchWorkItem?
    private var statusRestoreWork: DispatchWorkItem?
    private var harperWork: DispatchWorkItem?
    private var harperRequestID = UUID()
    private var isApplyingHarper = false
    private var isApplyingLanguageStyle = false
    private var suppressChangeTracking = false
    private var hasShownSplash = false
    private var eraMenuOverlay: EraMenuOverlay?
    private var fontChooserOverlay: FontChooserOverlay?
    private var editorWidthConstraint: NSLayoutConstraint?
    private var editorTopConstraint: NSLayoutConstraint?
    private var editorBottomConstraint: NSLayoutConstraint?
    private var editorWidthRatio: CGFloat = {
        let saved = UserDefaults.standard.double(forKey: "writingWidthRatio")
        return saved > 0 ? CGFloat(saved) : 0.68
    }()
    private var glassAmount: CGFloat = {
        let defaults = UserDefaults.standard
        if defaults.integer(forKey: "liquidGlassDefaultVersion") < 2 {
            defaults.set(2, forKey: "liquidGlassDefaultVersion")
            defaults.set(1.0, forKey: "liquidGlassAmount")
            return 1.0
        }
        guard defaults.object(forKey: "liquidGlassAmount") != nil else { return 1.0 }
        return CGFloat(defaults.double(forKey: "liquidGlassAmount"))
    }()

    init() {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 700, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)
        textView = FocusTextView(frame: .zero, textContainer: container)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = backdrop
        correctionEngine.mode = .wonderwriter
        configureEditor()
        configureHUD()
        configureSplash()
        installConstraints()
        backdrop.liquidGlassAmount = glassAmount
        applyTheme(.calm, restyleText: true)

        backdrop.onMouseActivity = { [weak self] in self?.revealHUD() }
        backdrop.onDoubleClick = { [weak self] in self?.enterFullScreen(nil) }
        backdrop.onEraCommand = { [weak self] command, event in self?.handleEraCommand(command, event: event) }
        textView.onTypingKey = { [weak self] key in self?.typingAudio.play(key) }
        textView.correctionEngine = correctionEngine
        correctionEngine.configure(textView)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Applying the first room before the window has real bounds can leave the
        // backdrop's display pass showing its construction-time placeholder.
        // Re-assert it now that the window is visible, without touching the document.
        applyTheme(currentTheme.id, restyleText: false)
        backdrop.needsDisplay = true
        view.window?.makeFirstResponder(textView)
        if hasShownSplash {
            revealHUD(for: 4.5)
        } else {
            showOpeningSplashIfNeeded()
        }

        // Asked once, once the room is up. Nothing waits on the answer, and
        // nothing is shown if it does not come.
        if !hasCheckedForUpdates {
            hasCheckedForUpdates = true
            updates.check()
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateEditorVerticalBounds()
    }

    private func configureEditor() {
        textView.delegate = self
        textView.frame = NSRect(x: 0, y: 0, width: 700, height: 650)
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 58, height: 54)
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.isAutomaticLinkDetectionEnabled = false
        textView.usesFindBar = true
        textView.usesInspectorBar = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.heightTracksTextView = false
        textView.string = ""

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.wantsLayer = true
        backdrop.addSubview(scrollView)
    }

    private func configureHUD() {
        hud.material = .hudWindow
        hud.blendingMode = .withinWindow
        hud.state = .active
        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.wantsLayer = true
        hud.layer?.cornerRadius = 13
        hud.layer?.masksToBounds = true

        themePopup.addItems(withTitles: WritingTheme.all.map(\.name))
        for (index, item) in themePopup.itemArray.enumerated() {
            item.tag = index
            item.target = self
            item.action = #selector(setThemeFromMenu(_:))
        }
        themePopup.selectItem(at: 0)
        themePopup.target = nil
        themePopup.action = nil
        themePopup.toolTip = "Writing world"

        correctionPopup.addItems(withTitles: CorrectionMode.allCases.map(\.title))
        for (index, item) in correctionPopup.itemArray.enumerated() {
            item.tag = index
            item.target = self
            item.action = #selector(setCorrectionFromMenu(_:))
        }
        correctionPopup.selectItem(at: CorrectionMode.wonderwriter.rawValue)
        correctionPopup.target = nil
        correctionPopup.action = nil
        correctionPopup.toolTip = "Correction strength"

        configureIconButton(typingButton, symbol: "keyboard", tooltip: "Typing sounds", action: #selector(toggleTypingSounds(_:)))
        configureIconButton(musicButton, symbol: "music.note", tooltip: "Loop music", action: #selector(toggleMusic(_:)))

        configureIconButton(folderButton, symbol: "folder", tooltip: "Open this world's music folder", action: #selector(openMusicFolder(_:)))

        configureIconButton(fullScreenButton, symbol: "arrow.up.left.and.arrow.down.right", tooltip: "Enter or leave full screen", action: #selector(enterFullScreen(_:)))

        configureIconButton(fontButton, symbol: "textformat", tooltip: "Choose any installed font", action: #selector(showFontPanel(_:)))

        footnoteButton.title = "¹"
        footnoteButton.target = self
        footnoteButton.action = #selector(insertFootnote(_:))
        footnoteButton.bezelStyle = .texturedRounded
        footnoteButton.toolTip = "Insert an interactive footnote (⌥⌘F)"

        smallerButton.title = "A−"
        smallerButton.target = self
        smallerButton.action = #selector(decreaseFontSize(_:))
        smallerButton.bezelStyle = .texturedRounded
        smallerButton.toolTip = "Smaller type"
        largerButton.title = "A+"
        largerButton.target = self
        largerButton.action = #selector(increaseFontSize(_:))
        largerButton.bezelStyle = .texturedRounded
        largerButton.toolTip = "Larger type"

        configureSliders()

        countLabel.alignment = .right
        countLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        countLabel.textColor = .secondaryLabelColor
        countLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        // The version stamp sits at the far end of the strip, past the word
        // count: the last thing in the room, and the only place a stale build
        // ever says so. It is a button in every state, because asking "am I
        // current?" is a fair question whether or not anything turned up.
        updateStamp.isBordered = false
        updateStamp.setButtonType(.momentaryChange)
        updateStamp.target = self
        updateStamp.action = #selector(showUpdateCard(_:))
        updateStamp.toolTip = "Which version this is, and whether a newer one has been cut."
        updateStamp.setContentCompressionResistancePriority(.required, for: .horizontal)
        updates.onChange = { [weak self] in self?.refreshUpdateStamp() }
        refreshUpdateStamp()

        let stack = NSStackView(views: [
            themePopup, fullScreenButton, fontButton, footnoteButton, smallerButton, largerButton,
            typingButton, musicButton, folderButton, widthControl, glassControl,
            correctionPopup, countLabel, updateStamp
        ])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        hud.addSubview(stack)
        backdrop.addSubview(hud)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: hud.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: hud.trailingAnchor),
            stack.topAnchor.constraint(equalTo: hud.topAnchor),
            stack.bottomAnchor.constraint(equalTo: hud.bottomAnchor),
            countLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
            writingWidthSlider.widthAnchor.constraint(equalToConstant: 78),
            glassTintSlider.widthAnchor.constraint(equalToConstant: 78)
        ])
        syncButtonStates()
    }

    private func configureSliders() {
        writingWidthSlider.minValue = 0.32
        writingWidthSlider.maxValue = 0.96
        writingWidthSlider.doubleValue = Double(editorWidthRatio)
        writingWidthSlider.isContinuous = true
        writingWidthSlider.target = self
        writingWidthSlider.action = #selector(writingWidthChanged(_:))
        writingWidthSlider.toolTip = "Writing width — narrow to room-filling"
        let widthIcon = NSImageView(image: NSImage(systemSymbolName: "arrow.left.and.right", accessibilityDescription: "Writing width") ?? NSImage())
        widthIcon.toolTip = writingWidthSlider.toolTip
        widthControl.orientation = .horizontal
        widthControl.alignment = .centerY
        widthControl.spacing = 4
        widthControl.addArrangedSubview(widthIcon)
        widthControl.addArrangedSubview(writingWidthSlider)

        glassTintSlider.minValue = 0
        glassTintSlider.maxValue = 1
        glassTintSlider.doubleValue = Double(glassAmount)
        glassTintSlider.isContinuous = true
        glassTintSlider.target = self
        glassTintSlider.action = #selector(glassTintChanged(_:))
        glassTintSlider.toolTip = "Liquid Glass — absolutely clear to deeply tinted"
        let glassIcon = NSImageView(image: NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "Glass tint") ?? NSImage())
        glassIcon.toolTip = glassTintSlider.toolTip
        glassControl.orientation = .horizontal
        glassControl.alignment = .centerY
        glassControl.spacing = 4
        glassControl.addArrangedSubview(glassIcon)
        glassControl.addArrangedSubview(glassTintSlider)
        glassControl.isHidden = true
    }

    private func configureSplash() {
        splash.material = .popover
        splash.blendingMode = .withinWindow
        splash.state = .active
        splash.translatesAutoresizingMaskIntoConstraints = false
        splash.wantsLayer = true
        splash.layer?.cornerRadius = 28
        splash.layer?.masksToBounds = true
        splash.layer?.borderWidth = 1
        splash.layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.66).cgColor

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Hello, Word")
        title.alignment = .center
        title.font = .systemFont(ofSize: 27, weight: .semibold)
        title.textColor = .labelColor

        let description = NSTextField(wrappingLabelWithString: "A private writing room for the first word,\nand every word after.")
        description.alignment = .center
        description.font = .systemFont(ofSize: 14, weight: .regular)
        description.textColor = .secondaryLabelColor

        let promise = NSTextField(labelWithString: "WRITE  ·  LISTEN  ·  DISAPPEAR")
        promise.alignment = .center
        promise.font = .monospacedSystemFont(ofSize: 9.5, weight: .medium)
        promise.textColor = .tertiaryLabelColor

        let stack = NSStackView(views: [icon, title, description, promise])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        splash.addSubview(stack)
        backdrop.addSubview(splash)

        NSLayoutConstraint.activate([
            splash.centerXAnchor.constraint(equalTo: backdrop.centerXAnchor),
            splash.centerYAnchor.constraint(equalTo: backdrop.centerYAnchor),
            splash.widthAnchor.constraint(equalToConstant: 338),
            splash.heightAnchor.constraint(equalToConstant: 238),
            stack.centerXAnchor.constraint(equalTo: splash.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: splash.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: splash.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: splash.trailingAnchor, constant: -24),
            icon.widthAnchor.constraint(equalToConstant: 58),
            icon.heightAnchor.constraint(equalToConstant: 58)
        ])
    }

    private func showOpeningSplashIfNeeded() {
        guard !hasShownSplash else { return }
        hasShownSplash = true
        hud.isHidden = true
        hud.alphaValue = 0
        splash.isHidden = false
        splash.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            splash.animator().alphaValue = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.62
                self.splash.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.splash.isHidden = true
                self?.revealHUD(for: 4.5)
            })
        }
    }

    private func configureIconButton(_ button: NSButton, symbol: String, tooltip: String, action: Selector) {
        button.title = ""
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        button.imagePosition = .imageOnly
        button.bezelStyle = .texturedRounded
        button.target = self
        button.action = action
        button.toolTip = tooltip
    }

    private func handleEraCommand(_ command: EraCommand, event: NSEvent) {
        switch command {
        case .minimize:
            view.window?.performMiniaturize(nil)
        case .zoom:
            view.window?.performZoom(nil)
        case .close:
            view.window?.performClose(nil)
        case .save:
            saveDocument(nil)
        case .hideControls:
            toggleInterface(nil)
        case .app:
            popUpEraMenu(appEraMenu(), event: event)
        case .file:
            popUpEraMenu(fileEraMenu(), event: event)
        case .edit:
            popUpEraMenu(editEraMenu(), event: event)
        case .format:
            popUpEraMenu(formatEraMenu(), event: event)
        case .world:
            popUpEraMenu(worldEraMenu(), event: event)
        case .sound:
            popUpEraMenu(soundEraMenu(), event: event)
        case .search:
            popUpEraMenu(searchEraMenu(), event: event)
        case .help:
            popUpEraMenu(helpEraMenu(), event: event)
        case .start:
            popUpEraMenu(startEraMenu(), event: event)
        }
    }

    private func popUpEraMenu(_ menu: NSMenu, event: NSEvent) {
        eraMenuOverlay?.removeFromSuperview()
        let anchor = backdrop.convert(event.locationInWindow, from: nil)
        let overlay = EraMenuOverlay(frame: backdrop.bounds, menu: menu, theme: currentTheme, anchor: anchor)
        overlay.autoresizingMask = [.width, .height]
        overlay.onDismiss = { [weak self, weak overlay] in
            if self?.eraMenuOverlay === overlay { self?.eraMenuOverlay = nil }
            self?.view.window?.makeFirstResponder(self?.textView)
        }
        backdrop.addSubview(overlay, positioned: .above, relativeTo: nil)
        eraMenuOverlay = overlay
    }

    private func prepareThemedMenu(_ menu: NSMenu, minimumWidth: CGFloat = 272) {
        let dark = [.dos, .spaceAge, .cyberdeck, .hell].contains(currentTheme.id)
        menu.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        menu.minimumWidth = minimumWidth
        for item in menu.items {
            if item.isSeparatorItem {
                item.view = EraMenuSeparatorView(theme: currentTheme, width: minimumWidth)
            } else if let submenu = item.submenu {
                prepareThemedMenu(submenu, minimumWidth: minimumWidth)
                item.attributedTitle = NSAttributedString(
                    string: item.title,
                    attributes: [
                        .font: currentTheme.prefersPixelEdges ? NSFont.monospacedSystemFont(ofSize: 13, weight: .medium) : currentTheme.font(size: 13),
                        .foregroundColor: currentTheme.textColor
                    ]
                )
            } else {
                item.view = EraMenuItemView(item: item, theme: currentTheme, width: minimumWidth)
            }
        }
    }

    private func stylePopupMenusForTheme() {
        for (index, item) in themePopup.itemArray.enumerated() {
            item.state = index == ThemeID.allCases.firstIndex(of: currentTheme.id) ? .on : .off
        }
        for (index, item) in correctionPopup.itemArray.enumerated() {
            item.state = index == correctionEngine.mode.rawValue ? .on : .off
        }
        if let menu = themePopup.menu { prepareThemedMenu(menu, minimumWidth: 286) }
        if let menu = correctionPopup.menu { prepareThemedMenu(menu, minimumWidth: 286) }
    }

    private func eraItem(_ title: String, action: Selector, target: AnyObject? = nil, key: String = "") -> NSMenuItem {
        let result = NSMenuItem(title: title, action: action, keyEquivalent: key)
        result.target = target
        return result
    }

    private func eraFindItem(_ title: String, action: NSTextFinder.Action, key: String = "") -> NSMenuItem {
        let result = eraItem(title, action: #selector(NSTextView.performTextFinderAction(_:)), key: key)
        result.tag = Int(action.rawValue)
        return result
    }

    private func appEraMenu() -> NSMenu {
        let menu = NSMenu(title: "Hello, Word")
        menu.addItem(eraItem("About Hello, Word", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), target: NSApp))
        menu.addItem(.separator())
        menu.addItem(eraItem("Enter or Leave Full Screen", action: #selector(enterFullScreen(_:)), target: self))
        return menu
    }

    private func fileEraMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.addItem(eraItem("New", action: #selector(newDocument(_:)), target: self, key: "n"))
        menu.addItem(eraItem("Open…", action: #selector(openDocument(_:)), target: self, key: "o"))
        menu.addItem(.separator())
        menu.addItem(eraItem("Save", action: #selector(saveDocument(_:)), target: self, key: "s"))
        menu.addItem(eraItem("Save As…", action: #selector(saveDocumentAs(_:)), target: self))
        return menu
    }

    private func editEraMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(eraItem("Undo", action: Selector(("undo:")), key: "z"))
        menu.addItem(eraItem("Redo", action: Selector(("redo:"))))
        menu.addItem(.separator())
        menu.addItem(eraItem("Cut", action: #selector(NSText.cut(_:)), key: "x"))
        menu.addItem(eraItem("Copy", action: #selector(NSText.copy(_:)), key: "c"))
        menu.addItem(eraItem("Paste", action: #selector(NSText.paste(_:)), key: "v"))
        menu.addItem(eraItem("Select All", action: #selector(NSText.selectAll(_:)), key: "a"))
        menu.addItem(.separator())
        menu.addItem(eraFindItem("Find…", action: .showFindInterface, key: "f"))
        menu.addItem(eraFindItem("Find and Replace…", action: .showReplaceInterface))
        return menu
    }

    private func formatEraMenu() -> NSMenu {
        let menu = NSMenu(title: "Format")
        menu.addItem(eraItem("Choose Font…", action: #selector(showFontPanel(_:)), target: self))
        menu.addItem(eraItem("Insert Footnote", action: #selector(insertFootnote(_:)), target: self))
        menu.addItem(.separator())
        menu.addItem(eraItem("Right to Left — Persian", action: #selector(setParagraphRightToLeft(_:)), target: self))
        menu.addItem(eraItem("Left to Right — English", action: #selector(setParagraphLeftToRight(_:)), target: self))
        return menu
    }

    private func worldEraMenu() -> NSMenu {
        let menu = NSMenu(title: "World")
        for (index, theme) in WritingTheme.all.enumerated() {
            let item = eraItem(theme.name, action: #selector(setThemeFromMenu(_:)), target: self)
            item.tag = index
            item.state = theme.id == currentTheme.id ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    private func soundEraMenu() -> NSMenu {
        let menu = NSMenu(title: "Sound")
        let typing = eraItem("Typing Sounds", action: #selector(toggleTypingSounds(_:)), target: self)
        typing.state = typingAudio.isEnabled ? .on : .off
        menu.addItem(typing)
        let music = eraItem("Loop Music", action: #selector(toggleMusic(_:)), target: self)
        music.state = musicLibrary.isEnabled ? .on : .off
        menu.addItem(music)
        menu.addItem(.separator())
        menu.addItem(eraItem("Open This World’s Music Folder…", action: #selector(openMusicFolder(_:)), target: self))
        return menu
    }

    private func searchEraMenu() -> NSMenu {
        let menu = NSMenu(title: "Search")
        menu.addItem(eraFindItem("Find…", action: .showFindInterface, key: "f"))
        menu.addItem(eraFindItem("Find and Replace…", action: .showReplaceInterface))
        menu.addItem(eraFindItem("Find Next", action: .nextMatch, key: "g"))
        menu.addItem(eraFindItem("Find Previous", action: .previousMatch))
        return menu
    }

    private func helpEraMenu() -> NSMenu {
        let menu = NSMenu(title: "Help")
        let room = NSMenuItem(title: currentTheme.subtitle, action: nil, keyEquivalent: "")
        room.isEnabled = false
        menu.addItem(room)
        menu.addItem(.separator())
        menu.addItem(eraItem("About Hello, Word", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), target: NSApp))
        return menu
    }

    private func startEraMenu() -> NSMenu {
        let menu = NSMenu(title: "Start")
        menu.addItem(eraItem("Open…", action: #selector(openDocument(_:)), target: self))
        menu.addItem(eraItem("Show or Hide Controls", action: #selector(toggleInterface(_:)), target: self))
        menu.addItem(eraItem("Enter or Leave Full Screen", action: #selector(enterFullScreen(_:)), target: self))
        menu.addItem(.separator())
        let worlds = NSMenuItem(title: "World", action: nil, keyEquivalent: "")
        worlds.submenu = worldEraMenu()
        menu.addItem(worlds)
        let sound = NSMenuItem(title: "Sound", action: nil, keyEquivalent: "")
        sound.submenu = soundEraMenu()
        menu.addItem(sound)
        return menu
    }

    private func installConstraints() {
        let proportionalWidth = scrollView.widthAnchor.constraint(equalTo: backdrop.widthAnchor, multiplier: editorWidthRatio)
        let top = scrollView.topAnchor.constraint(equalTo: backdrop.topAnchor, constant: 42)
        let bottom = scrollView.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor, constant: -42)
        editorWidthConstraint = proportionalWidth
        editorTopConstraint = top
        editorBottomConstraint = bottom
        NSLayoutConstraint.activate([
            scrollView.centerXAnchor.constraint(equalTo: backdrop.centerXAnchor),
            top,
            bottom,
            proportionalWidth,
            scrollView.widthAnchor.constraint(lessThanOrEqualTo: backdrop.widthAnchor, constant: -24),
            scrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),

            hud.centerXAnchor.constraint(equalTo: backdrop.centerXAnchor),
            hud.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor, constant: -14),
            hud.widthAnchor.constraint(lessThanOrEqualTo: backdrop.widthAnchor, constant: -28)
        ])
    }

    private func applyTheme(_ id: ThemeID, restyleText: Bool) {
        currentTheme = .theme(id)
        let widthMaximum = maximumWritingWidth(for: id)
        let widthKey = "writingWidthRatio.\(id.rawValue)"
        let storedWidth = UserDefaults.standard.object(forKey: widthKey) == nil
            ? (id == .typewriter ? widthMaximum : 0.68)
            : CGFloat(UserDefaults.standard.double(forKey: widthKey))
        editorWidthRatio = max(CGFloat(writingWidthSlider.minValue), min(widthMaximum, storedWidth))
        writingWidthSlider.maxValue = Double(widthMaximum)
        writingWidthSlider.doubleValue = Double(editorWidthRatio)
        replaceEditorWidthConstraint()
        updateEditorVerticalBounds()
        backdrop.theme = currentTheme
        typingAudio.profile = currentTheme.typingProfile
        musicLibrary.activate(id)

        // Every world reaches the edge of the window. Liquid Glass is the one world
        // whose edge is the real desktop behind the app rather than a rendered scene.
        view.window?.isOpaque = false
        view.window?.backgroundColor = .clear

        textView.wantsLayer = true
        let adaptiveGlass = id == .liquidGlass
        textView.layer?.compositingFilter = adaptiveGlass ? CIFilter(name: "CIDifferenceBlendMode") : nil
        let writingColor = adaptiveGlass ? NSColor.white : currentTheme.textColor
        let insertionColor = adaptiveGlass ? NSColor.white : currentTheme.insertionColor
        textView.textColor = writingColor
        textView.insertionPointColor = insertionColor
        textView.selectedTextAttributes = [
            .backgroundColor: writingColor.withAlphaComponent(0.24),
            .foregroundColor: writingColor
        ]
        textView.linkTextAttributes = [
            .foregroundColor: insertionColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        switch id {
        case .typewriter:
            textView.textContainerInset = NSSize(width: 30, height: 28)
        case .mac1999, .system95:
            textView.textContainerInset = NSSize(width: 24, height: 38)
        case .dos:
            textView.textContainerInset = NSSize(width: 18, height: 34)
        default:
            textView.textContainerInset = NSSize(width: 28, height: 46)
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = currentTheme.lineSpacing
        paragraph.paragraphSpacing = currentTheme.lineSpacing * 0.25
        paragraph.lineBreakMode = .byWordWrapping
        let font = currentTheme.font()

        textView.defaultParagraphStyle = paragraph
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: writingColor,
            .paragraphStyle: paragraph
        ]
        if let shadow = textShadow(for: id) { attributes[.shadow] = shadow }
        textView.typingAttributes = attributes
        if restyleText, let storage = textView.textStorage, storage.length > 0 {
            let range = NSRange(location: 0, length: storage.length)
            storage.removeAttribute(.shadow, range: range)
            storage.addAttributes(attributes, range: range)
        }
        applyLanguageStylingToDocument()

        styleEditorSurface()
        styleHUDForTheme()
        themePopup.selectItem(at: ThemeID.allCases.firstIndex(of: id) ?? 0)
        stylePopupMenusForTheme()
        showTransientStatus(currentTheme.subtitle)
    }

    private func styleEditorSurface() {
        guard let layer = scrollView.layer else { return }
        // The adjustable writing boundary is spatial, never a visible generic page.
        layer.backgroundColor = NSColor.clear.cgColor
        layer.cornerRadius = 0
        layer.borderWidth = 0
        layer.shadowOpacity = 0
    }

    private func textShadow(for id: ThemeID) -> NSShadow? {
        let shadow = NSShadow()
        shadow.shadowOffset = .zero
        switch id {
        case .spaceAge, .hell:
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.86)
            shadow.shadowBlurRadius = 5
            return shadow
        case .cyberdeck:
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.96)
            shadow.shadowBlurRadius = 7
            return shadow
        case .liquidGlass:
            return nil
        default:
            return nil
        }
    }

    private func styleHUDForTheme() {
        glassControl.isHidden = currentTheme.id != .liquidGlass

        let pixel = currentTheme.id == .mac1999 || currentTheme.id == .system95 || currentTheme.id == .dos
        let dark = currentTheme.id == .dos || currentTheme.id == .spaceAge || currentTheme.id == .cyberdeck || currentTheme.id == .hell
        hud.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        hud.blendingMode = currentTheme.id == .liquidGlass ? .behindWindow : .withinWindow
        hud.state = .active
        hud.layer?.cornerRadius = pixel ? 0 : (currentTheme.id == .liquidGlass ? 18 : 10)
        hud.layer?.borderWidth = 1

        let foreground: NSColor
        let panel: NSColor
        let border: NSColor
        let buttonFill: NSColor
        switch currentTheme.id {
        case .calm:
            foreground = NSColor(calibratedRed: 0.19, green: 0.15, blue: 0.10, alpha: 1)
            panel = NSColor(calibratedRed: 0.97, green: 0.90, blue: 0.76, alpha: 0.78)
            border = NSColor(calibratedWhite: 1, alpha: 0.55)
            buttonFill = NSColor(calibratedWhite: 1, alpha: 0.32)
        case .mac1999:
            foreground = .black
            panel = NSColor(calibratedWhite: 0.82, alpha: 0.98)
            border = NSColor(calibratedWhite: 0.25, alpha: 1)
            buttonFill = NSColor(calibratedWhite: 0.78, alpha: 1)
        case .system95:
            foreground = .black
            panel = NSColor(calibratedWhite: 0.75, alpha: 1)
            border = NSColor(calibratedWhite: 0.18, alpha: 1)
            buttonFill = NSColor(calibratedWhite: 0.76, alpha: 1)
        case .dos:
            foreground = NSColor(calibratedRed: 0.32, green: 1, blue: 0.56, alpha: 1)
            panel = NSColor(calibratedRed: 0.005, green: 0.025, blue: 0.015, alpha: 0.94)
            border = foreground.withAlphaComponent(0.72)
            buttonFill = NSColor(calibratedRed: 0.03, green: 0.12, blue: 0.065, alpha: 1)
        case .typewriter:
            foreground = NSColor(calibratedRed: 0.18, green: 0.095, blue: 0.04, alpha: 1)
            panel = NSColor(calibratedRed: 0.80, green: 0.69, blue: 0.49, alpha: 0.94)
            border = NSColor(calibratedRed: 0.25, green: 0.12, blue: 0.045, alpha: 1)
            buttonFill = NSColor(calibratedRed: 0.94, green: 0.86, blue: 0.68, alpha: 1)
        case .library:
            foreground = NSColor(calibratedRed: 0.20, green: 0.12, blue: 0.06, alpha: 1)
            panel = NSColor(calibratedRed: 0.91, green: 0.79, blue: 0.57, alpha: 0.91)
            border = NSColor(calibratedRed: 0.43, green: 0.27, blue: 0.12, alpha: 0.76)
            buttonFill = NSColor(calibratedRed: 0.97, green: 0.89, blue: 0.72, alpha: 0.96)
        case .spaceAge:
            foreground = NSColor(calibratedRed: 1, green: 0.72, blue: 0.28, alpha: 1)
            panel = NSColor(calibratedRed: 0.035, green: 0.12, blue: 0.15, alpha: 0.94)
            border = NSColor(calibratedRed: 0.92, green: 0.34, blue: 0.12, alpha: 0.86)
            buttonFill = NSColor(calibratedRed: 0.08, green: 0.24, blue: 0.27, alpha: 1)
        case .cyberdeck:
            foreground = NSColor(calibratedRed: 0.42, green: 1, blue: 0.94, alpha: 1)
            panel = NSColor(calibratedRed: 0.012, green: 0.025, blue: 0.075, alpha: 0.96)
            border = NSColor(calibratedRed: 1, green: 0.08, blue: 0.62, alpha: 0.86)
            buttonFill = NSColor(calibratedRed: 0.025, green: 0.10, blue: 0.16, alpha: 1)
        case .hell:
            foreground = NSColor(calibratedRed: 0.86, green: 0.76, blue: 0.64, alpha: 1)
            panel = NSColor(calibratedRed: 0.025, green: 0.006, blue: 0.008, alpha: 0.97)
            border = NSColor(calibratedRed: 0.48, green: 0.045, blue: 0.030, alpha: 0.82)
            buttonFill = NSColor(calibratedRed: 0.085, green: 0.012, blue: 0.014, alpha: 1)
        case .liquidGlass:
            foreground = NSColor(calibratedWhite: 0.11, alpha: 0.92)
            panel = NSColor(calibratedWhite: 1, alpha: 0.10 + glassAmount * 0.12)
            border = NSColor(calibratedWhite: 1, alpha: 0.62)
            buttonFill = NSColor(calibratedWhite: 1, alpha: 0.16)
        }

        hud.layer?.backgroundColor = panel.cgColor
        hud.layer?.borderColor = border.cgColor
        countLabel.textColor = foreground
        // Every room has its own ink, so the stamp takes its colour from the
        // room rather than from the system — except when it has something to
        // say, which has to read in all ten of them.
        stampColor = foreground.withAlphaComponent(0.72)
        refreshUpdateStamp()

        let buttonStyle: NSButton.BezelStyle = pixel ? .regularSquare : .texturedRounded
        let controls = [fullScreenButton, fontButton, footnoteButton, smallerButton, largerButton, typingButton, musicButton, folderButton]
        for control in controls {
            control.bezelStyle = buttonStyle
            control.bezelColor = buttonFill
            control.contentTintColor = foreground
            control.font = pixel ? NSFont.monospacedSystemFont(ofSize: 11, weight: .medium) : currentTheme.font(size: 11)
        }
        for popup in [themePopup, correctionPopup] {
            popup.bezelStyle = buttonStyle
            popup.bezelColor = buttonFill
            popup.contentTintColor = foreground
            popup.font = pixel ? NSFont.monospacedSystemFont(ofSize: 11, weight: .medium) : currentTheme.font(size: 11)
        }
        for case let imageView as NSImageView in widthControl.arrangedSubviews + glassControl.arrangedSubviews {
            imageView.contentTintColor = foreground
        }
    }

    func textDidChange(_ notification: Notification) {
        guard !suppressChangeTracking, !isApplyingLanguageStyle else { return }
        applyLanguageStylingAroundCursor()
        isDirty = true
        updateWordCount()
        updateWindowTitle()
        scheduleAutosave()
        scheduleHarperCheck()
    }

    private func applyLanguageStylingAroundCursor() {
        let document = textView.string as NSString
        guard document.length > 0 else { return }
        let cursor = min(textView.selectedRange().location, document.length)
        let paragraphRange = document.paragraphRange(for: NSRange(location: cursor, length: 0))
        applyLanguageStyling(to: paragraphRange)
    }

    private func applyLanguageStylingToDocument() {
        guard let storage = textView.textStorage, storage.length > 0 else { return }
        let document = storage.string as NSString
        var location = 0
        while location < document.length {
            let paragraphRange = document.paragraphRange(for: NSRange(location: location, length: 0))
            applyLanguageStyling(to: paragraphRange)
            let next = NSMaxRange(paragraphRange)
            guard next > location else { break }
            location = next
        }
    }

    private func applyLanguageStyling(to paragraphRange: NSRange) {
        guard let storage = textView.textStorage,
              paragraphRange.location != NSNotFound,
              NSMaxRange(paragraphRange) <= storage.length,
              paragraphRange.length > 0 else { return }

        let paragraphText = (storage.string as NSString).substring(with: paragraphRange)
        guard let direction = strongWritingDirection(in: paragraphText) else { return }

        isApplyingLanguageStyle = true
        storage.beginEditing()

        let existing = storage.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle
        let paragraph = (existing?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        paragraph.lineSpacing = currentTheme.lineSpacing
        paragraph.paragraphSpacing = currentTheme.lineSpacing * 0.25
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.baseWritingDirection = direction
        paragraph.alignment = direction == .rightToLeft ? .right : .left
        storage.addAttribute(.paragraphStyle, value: paragraph, range: paragraphRange)

        // Apply a Persian-aware face only to Arabic-script runs. English in the same
        // paragraph keeps the room's Latin typeface.
        let local = paragraphText as NSString
        var runStart: Int?
        for index in 0..<local.length {
            let isArabic = isArabicScriptCodeUnit(local.character(at: index))
            if isArabic, runStart == nil { runStart = index }
            if !isArabic, let start = runStart {
                applyPersianFont(to: NSRange(location: paragraphRange.location + start, length: index - start), storage: storage)
                runStart = nil
            }
        }
        if let start = runStart {
            applyPersianFont(to: NSRange(location: paragraphRange.location + start, length: local.length - start), storage: storage)
        }

        storage.endEditing()
        if paragraphRange.contains(textView.selectedRange().location) || NSMaxRange(paragraphRange) == textView.selectedRange().location {
            textView.typingAttributes[.paragraphStyle] = paragraph
            if direction == .rightToLeft {
                let size = (textView.typingAttributes[.font] as? NSFont)?.pointSize ?? currentTheme.defaultFontSize
                textView.typingAttributes[.font] = currentTheme.persianFont(size: size)
            }
        }
        isApplyingLanguageStyle = false
    }

    private func applyPersianFont(to range: NSRange, storage: NSTextStorage) {
        guard range.length > 0 else { return }
        let existing = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
        let size = existing?.pointSize ?? textView.font?.pointSize ?? currentTheme.defaultFontSize
        storage.addAttribute(.font, value: currentTheme.persianFont(size: size), range: range)
    }

    private func strongWritingDirection(in text: String) -> NSWritingDirection? {
        for scalar in text.unicodeScalars {
            if isArabicScriptScalar(scalar.value) { return .rightToLeft }
            if CharacterSet.letters.contains(scalar) { return .leftToRight }
        }
        return nil
    }

    private func isArabicScriptCodeUnit(_ value: unichar) -> Bool {
        isArabicScriptScalar(UInt32(value))
    }

    private func isArabicScriptScalar(_ value: UInt32) -> Bool {
        (0x0600...0x06FF).contains(value) ||
        (0x0750...0x077F).contains(value) ||
        (0x08A0...0x08FF).contains(value) ||
        (0xFB50...0xFDFF).contains(value) ||
        (0xFE70...0xFEFF).contains(value)
    }

    private func updateWordCount() {
        let words = textView.string.split { $0.isWhitespace || $0.isNewline }.count
        countLabel.stringValue = "\(words) \(words == 1 ? "word" : "words")"
    }

    private func updateWindowTitle() {
        let base = currentURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
        view.window?.title = (isDirty ? "• " : "") + base + " — Hello, Word"
    }

    private func scheduleAutosave() {
        autosaveWork?.cancel()
        guard currentURL != nil else { return }
        let work = DispatchWorkItem { [weak self] in _ = self?.writeCurrentDocument() }
        autosaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func scheduleHarperCheck() {
        harperWork?.cancel()
        guard correctionEngine.mode == .wonderwriter, !isApplyingHarper, harper.isAvailable else { return }
        let requestID = UUID()
        harperRequestID = requestID
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.harperRequestID == requestID else { return }
            self.runHarperCheck(requestID: requestID)
        }
        harperWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95, execute: work)
    }

    private func runHarperCheck(requestID: UUID) {
        let document = textView.string as NSString
        guard document.length > 0 else { return }
        let cursor = min(textView.selectedRange().location, document.length)
        let probe = NSRange(location: max(0, cursor - 1), length: 0)
        var paragraphRange = document.paragraphRange(for: probe)
        if paragraphRange.length > 1_200 {
            paragraphRange = NSRange(location: NSMaxRange(paragraphRange) - 1_200, length: 1_200)
        }
        let original = document.substring(with: paragraphRange)
        guard original.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count >= 3 else { return }
        let arabicCount = original.unicodeScalars.reduce(into: 0) { count, scalar in
            if isArabicScriptScalar(scalar.value) { count += 1 }
        }
        let latinCount = original.unicodeScalars.reduce(into: 0) { count, scalar in
            if scalar.value <= 0x024F, CharacterSet.letters.contains(scalar) { count += 1 }
        }
        guard latinCount >= 3, latinCount >= arabicCount else { return }

        harper.check(original) { [weak self] corrections in
            guard let self, self.harperRequestID == requestID, !corrections.isEmpty else { return }
            self.applyHarper(corrections, to: original, documentRange: paragraphRange)
        }
    }

    private func applyHarper(_ corrections: [HarperCorrection], to original: String, documentRange: NSRange) {
        let currentDocument = textView.string as NSString
        guard NSMaxRange(documentRange) <= currentDocument.length,
              currentDocument.substring(with: documentRange) == original else { return }

        let corrected = NSMutableString(string: original)
        var applied = 0
        for correction in corrections.sorted(by: { $0.characterRange.lowerBound > $1.characterRange.lowerBound }) {
            guard let range = utf16Range(for: correction.characterRange, in: original),
                  NSMaxRange(range) <= corrected.length else { continue }
            corrected.replaceCharacters(in: range, with: correction.replacement)
            applied += 1
        }
        guard applied > 0, corrected as String != original else { return }

        isApplyingHarper = true
        if textView.shouldChangeText(in: documentRange, replacementString: corrected as String) {
            textView.textStorage?.replaceCharacters(in: documentRange, with: corrected as String)
            textView.didChangeText()
        }
        isApplyingHarper = false
        showTransientStatus("Hello, Word corrected \(applied) contextual \(applied == 1 ? "detail" : "details")")
    }

    private func utf16Range(for characterRange: Range<Int>, in text: String) -> NSRange? {
        guard characterRange.lowerBound >= 0,
              characterRange.upperBound <= text.count,
              let start = text.index(text.startIndex, offsetBy: characterRange.lowerBound, limitedBy: text.endIndex),
              let end = text.index(text.startIndex, offsetBy: characterRange.upperBound, limitedBy: text.endIndex) else {
            return nil
        }
        return NSRange(start..<end, in: text)
    }

    private func revealHUD(for duration: TimeInterval = 3.2) {
        hideHUDWork?.cancel()
        hud.isHidden = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            hud.animator().alphaValue = 1
        }
        let work = DispatchWorkItem { [weak self] in self?.hideHUD() }
        hideHUDWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func hideHUD() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.30
            hud.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            if self?.hud.alphaValue == 0 { self?.hud.isHidden = true }
        })
    }

    private func showTransientStatus(_ message: String) {
        statusRestoreWork?.cancel()
        countLabel.stringValue = message
        revealHUD(for: 3.3)
        let work = DispatchWorkItem { [weak self] in self?.updateWordCount() }
        statusRestoreWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: work)
    }

    /// The stamp is the whole of the notice: the version normally, and the
    /// version that is out once this build is behind. Nothing about it moves,
    /// animates, or asks to be read.
    private func refreshUpdateStamp() {
        let weight: NSFont.Weight = updates.hasUpdate ? .semibold : .regular
        updateStamp.attributedTitle = NSAttributedString(
            string: updates.stamp,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: weight),
                .foregroundColor: updates.hasUpdate ? .systemOrange : stampColor
            ]
        )

        // A card left open while an answer lands should not keep showing the
        // sentence it was opened with.
        if let card = presentedViewControllers?.first(where: { $0 is UpdateCardController }) as? UpdateCardController {
            card.refresh()
        }
    }

    /// Opened only from the stamp or from "Check for Updates…". The card never
    /// arrives on its own, and it is the only place the version numbers are
    /// written out in full.
    @objc func showUpdateCard(_ sender: Any?) {
        guard presentedViewControllers?.contains(where: { $0 is UpdateCardController }) != true else { return }
        presentAsSheet(UpdateCardController(updates: updates))
    }

    private func syncButtonStates() {
        typingButton.state = typingAudio.isEnabled ? .on : .off
        musicButton.state = musicLibrary.isEnabled ? .on : .off
        typingButton.contentTintColor = typingAudio.isEnabled ? .controlAccentColor : .secondaryLabelColor
        musicButton.contentTintColor = musicLibrary.isEnabled ? .controlAccentColor : .secondaryLabelColor
    }

    @objc private func themePopupChanged(_ sender: NSPopUpButton) {
        let index = max(0, sender.indexOfSelectedItem)
        applyTheme(ThemeID.allCases[index], restyleText: true)
        isDirty = true
        updateWindowTitle()
        view.window?.makeFirstResponder(textView)
    }

    @objc func setThemeFromMenu(_ sender: NSMenuItem) {
        guard ThemeID.allCases.indices.contains(sender.tag) else { return }
        applyTheme(ThemeID.allCases[sender.tag], restyleText: true)
        isDirty = true
        updateWindowTitle()
        view.window?.makeFirstResponder(textView)
    }

    @objc private func correctionPopupChanged(_ sender: NSPopUpButton) {
        setCorrectionMode(CorrectionMode(rawValue: sender.indexOfSelectedItem) ?? .balanced)
    }

    @objc func setCorrectionFromMenu(_ sender: NSMenuItem) {
        setCorrectionMode(CorrectionMode(rawValue: sender.tag) ?? .balanced)
    }

    private func setCorrectionMode(_ mode: CorrectionMode) {
        correctionEngine.mode = mode
        correctionEngine.configure(textView)
        correctionPopup.selectItem(at: mode.rawValue)
        stylePopupMenusForTheme()
        if mode == .wonderwriter && !harper.isAvailable {
            showTransientStatus("Hello, Word context engine is missing")
        } else {
            showTransientStatus(mode.title)
        }
        scheduleHarperCheck()
        view.window?.makeFirstResponder(textView)
    }

    @objc func toggleTypingSounds(_ sender: Any?) {
        typingAudio.isEnabled.toggle()
        syncButtonStates()
        showTransientStatus(typingAudio.isEnabled ? "Typing sounds on" : "Typing sounds off")
        view.window?.makeFirstResponder(textView)
    }

    @objc func toggleMusic(_ sender: Any?) {
        musicLibrary.isEnabled.toggle()
        syncButtonStates()
        let message: String
        if !musicLibrary.isEnabled {
            message = "Music off"
        } else if let track = musicLibrary.currentTrackName {
            message = "Playing \(track)"
        } else {
            message = "No music here yet — use the folder button"
        }
        showTransientStatus(message)
        view.window?.makeFirstResponder(textView)
    }

    @objc func openMusicFolder(_ sender: Any?) {
        musicLibrary.openCurrentThemeFolder()
        showTransientStatus("Opened \(currentTheme.name) music folder")
    }

    @objc func showFontPanel(_ sender: Any?) {
        fontChooserOverlay?.removeFromSuperview()
        let currentSize = textView.font?.pointSize ?? currentTheme.defaultFontSize
        let storage = textView.textStorage
        let location = min(textView.selectedRange().location, storage?.length ?? 0)
        let usesPersianPreview = storage.map { isRightToLeftParagraph(at: location, in: $0) } ?? false
        let chooser = FontChooserOverlay(
            frame: backdrop.bounds,
            theme: currentTheme,
            currentSize: currentSize,
            usesPersianPreview: usesPersianPreview
        )
        chooser.autoresizingMask = [.width, .height]
        chooser.onChoose = { [weak self] font in self?.applyChosenFont(font) }
        chooser.onDismiss = { [weak self, weak chooser] in
            if self?.fontChooserOverlay === chooser { self?.fontChooserOverlay = nil }
            self?.view.window?.makeFirstResponder(self?.textView)
        }
        backdrop.addSubview(chooser, positioned: .above, relativeTo: nil)
        fontChooserOverlay = chooser
    }

    private func applyChosenFont(_ font: NSFont) {
        if let storage = textView.textStorage, storage.length > 0 {
            let selection = textView.selectedRange()
            let range = selection.length > 0 ? selection : NSRange(location: 0, length: storage.length)
            storage.addAttribute(.font, value: font, range: range)
        }
        textView.font = font
        textView.typingAttributes[.font] = font
        isDirty = true
        updateWindowTitle()
        showTransientStatus(font.familyName ?? font.fontName)
    }

    @objc func increaseFontSize(_ sender: Any?) { changeFontSize(by: 1) }
    @objc func decreaseFontSize(_ sender: Any?) { changeFontSize(by: -1) }

    @objc func setParagraphRightToLeft(_ sender: Any?) {
        setSelectedParagraphDirection(.rightToLeft)
        showTransientStatus("راست‌به‌چپ — Right to left")
    }

    @objc func setParagraphLeftToRight(_ sender: Any?) {
        setSelectedParagraphDirection(.leftToRight)
        showTransientStatus("Left to right")
    }

    private func setSelectedParagraphDirection(_ direction: NSWritingDirection) {
        guard let storage = textView.textStorage, storage.length > 0 else {
            let paragraph = (textView.defaultParagraphStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            paragraph.baseWritingDirection = direction
            paragraph.alignment = direction == .rightToLeft ? .right : .left
            textView.typingAttributes[.paragraphStyle] = paragraph
            if direction == .rightToLeft {
                let size = (textView.typingAttributes[.font] as? NSFont)?.pointSize ?? currentTheme.defaultFontSize
                textView.typingAttributes[.font] = currentTheme.persianFont(size: size)
            }
            return
        }
        let paragraphRange = (storage.string as NSString).paragraphRange(for: textView.selectedRange())
        let existing = storage.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle
        let paragraph = (existing?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        paragraph.baseWritingDirection = direction
        paragraph.alignment = direction == .rightToLeft ? .right : .left
        storage.addAttribute(.paragraphStyle, value: paragraph, range: paragraphRange)
        textView.typingAttributes[.paragraphStyle] = paragraph
        view.window?.makeFirstResponder(textView)
    }

    @objc func insertFootnote(_ sender: Any?) {
        guard let storage = textView.textStorage else { return }
        let sourceLocation = min(NSMaxRange(textView.selectedRange()), storage.length)
        let isPersianFootnote = isRightToLeftParagraph(at: sourceLocation, in: storage)
        let number = nextFootnoteNumber(in: storage)
        let displayNumber = isPersianFootnote ? persianDigits(for: number) : "\(number)"
        let sourceURL = URL(string: "helloword-footnote://note/\(number)")!
        let noteURL = URL(string: "helloword-footnote://source/\(number)")!

        let baseFont = (textView.typingAttributes[.font] as? NSFont) ?? currentTheme.font()
        var markerAttributes = textView.typingAttributes
        markerAttributes[.font] = isPersianFootnote
            ? currentTheme.persianFont(size: max(10, baseFont.pointSize * 0.68))
            : currentTheme.font(size: max(10, baseFont.pointSize * 0.68))
        markerAttributes[.foregroundColor] = currentTheme.insertionColor
        markerAttributes[.superscript] = 1
        markerAttributes[.link] = sourceURL
        let marker = NSAttributedString(string: "[\(displayNumber)]", attributes: markerAttributes)

        guard textView.shouldChangeText(in: NSRange(location: sourceLocation, length: 0), replacementString: marker.string) else { return }
        storage.beginEditing()
        storage.insert(marker, at: sourceLocation)

        let englishHeader = "──────── Footnotes ────────"
        let persianHeader = "──────── پانویس ────────"
        let bilingualHeader = "──────── پانویس · Footnotes ────────"
        let footnoteHeader = isPersianFootnote ? persianHeader : englishHeader
        let appended = NSMutableAttributedString()
        let noteFont = isPersianFootnote
            ? currentTheme.persianFont(size: max(11, baseFont.pointSize * 0.78))
            : currentTheme.font(size: max(11, baseFont.pointSize * 0.78))
        var noteAttributes: [NSAttributedString.Key: Any] = [
            .font: noteFont,
            .foregroundColor: currentTheme.textColor
        ]
        let noteParagraph = NSMutableParagraphStyle()
        noteParagraph.lineSpacing = max(3, currentTheme.lineSpacing * 0.65)
        noteParagraph.paragraphSpacing = 3
        noteParagraph.baseWritingDirection = isPersianFootnote ? .rightToLeft : .leftToRight
        noteParagraph.alignment = isPersianFootnote ? .right : .left
        noteAttributes[.paragraphStyle] = noteParagraph

        var separatorAttributes = noteAttributes
        separatorAttributes[.foregroundColor] = currentTheme.textColor.withAlphaComponent(0.52)
        separatorAttributes[.font] = isPersianFootnote
            ? currentTheme.persianFont(size: max(10, baseFont.pointSize * 0.62))
            : currentTheme.font(size: max(10, baseFont.pointSize * 0.62))

        if storage.string.contains(isPersianFootnote ? englishHeader : persianHeader),
           !storage.string.contains(bilingualHeader) {
            let oldHeader = isPersianFootnote ? englishHeader : persianHeader
            let oldRange = (storage.string as NSString).range(of: oldHeader)
            if oldRange.location != NSNotFound {
                storage.replaceCharacters(
                    in: oldRange,
                    with: NSAttributedString(string: bilingualHeader, attributes: separatorAttributes)
                )
            }
        }

        let hasFootnoteHeader = storage.string.contains(englishHeader)
            || storage.string.contains(persianHeader)
            || storage.string.contains(bilingualHeader)
        if !hasFootnoteHeader {
            appended.append(NSAttributedString(string: "\n\n\(footnoteHeader)\n", attributes: separatorAttributes))
        } else if !storage.string.hasSuffix("\n") {
            appended.append(NSAttributedString(string: "\n", attributes: noteAttributes))
        }

        var labelAttributes = noteAttributes
        labelAttributes[.link] = noteURL
        labelAttributes[.foregroundColor] = currentTheme.insertionColor
        appended.append(NSAttributedString(string: "[\(displayNumber)]", attributes: labelAttributes))
        appended.append(NSAttributedString(string: " ", attributes: noteAttributes))

        storage.append(appended)
        let noteCursor = storage.length
        storage.endEditing()
        textView.didChangeText()
        textView.setSelectedRange(NSRange(location: noteCursor, length: 0))
        textView.scrollRangeToVisible(NSRange(location: max(0, noteCursor - 1), length: min(1, noteCursor)))
        view.window?.makeFirstResponder(textView)
        showTransientStatus(
            isPersianFootnote
                ? "پانویس \(displayNumber) — برای رفت‌وبرگشت روی شماره‌ها کلیک کنید"
                : "Footnote \(number) — click either number to jump"
        )
    }

    private func isRightToLeftParagraph(at location: Int, in storage: NSTextStorage) -> Bool {
        if storage.length > 0 {
            let document = storage.string as NSString
            let paragraphRange = document.paragraphRange(for: NSRange(location: min(location, document.length), length: 0))
            let paragraphText = document.substring(with: paragraphRange)
            if let direction = strongWritingDirection(in: paragraphText) {
                return direction == .rightToLeft
            }

            let attributeLocation = min(paragraphRange.location, storage.length - 1)
            if let style = storage.attribute(.paragraphStyle, at: attributeLocation, effectiveRange: nil) as? NSParagraphStyle,
               style.baseWritingDirection != .natural {
                return style.baseWritingDirection == .rightToLeft
            }
        }

        let typingStyle = textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle
        return typingStyle?.baseWritingDirection == .rightToLeft
    }

    private func nextFootnoteNumber(in storage: NSTextStorage) -> Int {
        var highest = 0
        if storage.length > 0 {
            storage.enumerateAttribute(.link, in: NSRange(location: 0, length: storage.length)) { value, _, _ in
                let url: URL?
                if let value = value as? URL { url = value }
                else if let value = value as? String { url = URL(string: value) }
                else { url = nil }
                guard url?.scheme == "helloword-footnote",
                      let component = url?.pathComponents.last,
                      let number = Int(component) else { return }
                highest = max(highest, number)
            }
        }
        if highest > 0 { return highest + 1 }

        let text = storage.string
        guard let expression = try? NSRegularExpression(pattern: #"(?m)^\[([0-9۰-۹٠-٩]+)\]"#) else { return 1 }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        for match in expression.matches(in: text, range: fullRange) where match.numberOfRanges > 1 {
            let digits = (text as NSString).substring(with: match.range(at: 1))
            highest = max(highest, westernNumber(from: digits) ?? 0)
        }
        return highest + 1
    }

    private func persianDigits(for number: Int) -> String {
        let digits = Array("۰۱۲۳۴۵۶۷۸۹")
        return String(String(number).compactMap { character in
            guard let value = character.wholeNumberValue else { return nil }
            return digits[value]
        })
    }

    private func westernNumber(from localizedDigits: String) -> Int? {
        var result = ""
        for scalar in localizedDigits.unicodeScalars {
            let value: UInt32
            switch scalar.value {
            case 0x30...0x39: value = scalar.value - 0x30
            case 0x06F0...0x06F9: value = scalar.value - 0x06F0
            case 0x0660...0x0669: value = scalar.value - 0x0660
            default: return nil
            }
            result.append(String(value))
        }
        return Int(result)
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        let url: URL?
        if let value = link as? URL {
            url = value
        } else if let value = link as? String {
            url = URL(string: value)
        } else {
            url = nil
        }
        guard let url, url.scheme == "helloword-footnote",
              let kind = url.host,
              let number = url.pathComponents.last else { return false }

        let opposite = kind == "note" ? "source" : "note"
        let target = "helloword-footnote://\(opposite)/\(number)"
        guard let storage = textView.textStorage else { return true }
        var destination = NSRange(location: NSNotFound, length: 0)
        storage.enumerateAttribute(.link, in: NSRange(location: 0, length: storage.length)) { value, range, stop in
            let candidate: String?
            if let url = value as? URL { candidate = url.absoluteString }
            else { candidate = value as? String }
            if candidate == target {
                destination = range
                stop.pointee = true
            }
        }
        guard destination.location != NSNotFound else { return true }
        textView.setSelectedRange(NSRange(location: destination.location, length: 0))
        textView.scrollRangeToVisible(destination)
        view.window?.makeFirstResponder(textView)
        showTransientStatus(kind == "note" ? "Footnote \(number)" : "Back to footnote \(number) in the text")
        return true
    }

    @objc private func writingWidthChanged(_ sender: NSSlider) {
        editorWidthRatio = CGFloat(sender.doubleValue)
        UserDefaults.standard.set(sender.doubleValue, forKey: "writingWidthRatio")
        UserDefaults.standard.set(sender.doubleValue, forKey: "writingWidthRatio.\(currentTheme.id.rawValue)")
        replaceEditorWidthConstraint()
        showTransientStatus("Writing width \(Int(sender.doubleValue * 100))%")
    }

    private func maximumWritingWidth(for id: ThemeID) -> CGFloat {
        switch id {
        case .typewriter: return 0.44
        case .mac1999, .system95: return 0.92
        case .dos: return 0.94
        case .library: return 0.52
        case .spaceAge: return 0.88
        case .cyberdeck: return 0.76
        default: return 0.96
        }
    }

    private func updateEditorVerticalBounds() {
        guard let top = editorTopConstraint, let bottom = editorBottomConstraint else { return }
        if currentTheme.id == .typewriter {
            // The art is aspect-filled, so its vertical crop changes with the window.
            // Map the upright paper rectangle from the 1536 x 1024 source into the
            // visible crop, then keep the editor just inside the actual sheet.
            let targetWidth = max(1, backdrop.bounds.width)
            let targetHeight = max(1, backdrop.bounds.height)
            let targetAspect = targetWidth / targetHeight
            let sourceWidth: CGFloat = 1536
            let sourceHeight: CGFloat = 1024
            let sourceAspect = sourceWidth / sourceHeight
            var visibleOriginY: CGFloat = 0
            var visibleHeight = sourceHeight
            if sourceAspect < targetAspect {
                visibleHeight = sourceWidth / targetAspect
                visibleOriginY = (sourceHeight - visibleHeight) * 0.5
            }

            // Source coordinates are AppKit-style here (origin at bottom-left).
            let paperBottom: CGFloat = 374
            let paperTop: CGFloat = 971
            let mappedBottom = (paperBottom - visibleOriginY) / visibleHeight * targetHeight
            let mappedTop = (paperTop - visibleOriginY) / visibleHeight * targetHeight
            let safeEdge: CGFloat = 8
            top.constant = max(0, targetHeight - mappedTop) + safeEdge
            bottom.constant = -(max(0, mappedBottom) + safeEdge)
        } else {
            top.constant = 42
            bottom.constant = -42
        }
    }

    private func replaceEditorWidthConstraint() {
        editorWidthConstraint?.isActive = false
        let constraint = scrollView.widthAnchor.constraint(equalTo: backdrop.widthAnchor, multiplier: editorWidthRatio)
        constraint.isActive = true
        editorWidthConstraint = constraint
        view.needsLayout = true
    }

    @objc private func glassTintChanged(_ sender: NSSlider) {
        glassAmount = CGFloat(sender.doubleValue)
        UserDefaults.standard.set(sender.doubleValue, forKey: "liquidGlassAmount")
        backdrop.liquidGlassAmount = glassAmount
        styleHUDForTheme()
        let percent = Int(sender.doubleValue * 100)
        showTransientStatus(percent == 0 ? "Liquid Glass — absolutely clear" : "Liquid Glass tint \(percent)%")
    }

    private func changeFontSize(by delta: CGFloat) {
        let existing = textView.font?.pointSize ?? currentTheme.defaultFontSize
        let size = max(11, min(48, existing + delta))
        let font = currentTheme.font(size: size)
        if let storage = textView.textStorage, storage.length > 0 {
            storage.addAttribute(.font, value: font, range: NSRange(location: 0, length: storage.length))
        }
        textView.font = font
        textView.typingAttributes[.font] = font
        isDirty = true
        updateWindowTitle()
        showTransientStatus("Type size \(Int(size))")
        view.window?.makeFirstResponder(textView)
    }

    @objc func toggleInterface(_ sender: Any?) {
        if hud.isHidden || hud.alphaValue == 0 { revealHUD(for: 8) } else { hideHUD() }
    }

    @objc func enterFullScreen(_ sender: Any?) {
        view.window?.toggleFullScreen(sender)
    }

    @objc func newDocument(_ sender: Any?) {
        guard confirmProceedPastUnsavedChanges() else { return }
        suppressChangeTracking = true
        textView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        suppressChangeTracking = false
        currentURL = nil
        isDirty = false
        applyTheme(currentTheme.id, restyleText: true)
        updateWordCount()
        updateWindowTitle()
        view.window?.makeFirstResponder(textView)
    }

    @objc func openDocument(_ sender: Any?) {
        guard confirmProceedPastUnsavedChanges() else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .rtf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            suppressChangeTracking = true
            if url.pathExtension.lowercased() == "rtf" {
                let attributed = try NSAttributedString(
                    url: url,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                )
                textView.textStorage?.setAttributedString(attributed)
            } else {
                textView.string = try String(contentsOf: url, encoding: .utf8)
                applyTheme(currentTheme.id, restyleText: true)
            }
            applyLanguageStylingToDocument()
            suppressChangeTracking = false
            currentURL = url
            isDirty = false
            updateWordCount()
            updateWindowTitle()
            view.window?.makeFirstResponder(textView)
        } catch {
            suppressChangeTracking = false
            presentError(title: "Couldn’t open that document", error: error)
        }
    }

    @objc func saveDocument(_ sender: Any?) {
        if currentURL == nil { _ = saveDocumentAs(nil) } else { _ = writeCurrentDocument() }
    }

    @objc @discardableResult func saveDocumentAs(_ sender: Any?) -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText, .rtf]
        panel.nameFieldStringValue = currentURL?.lastPathComponent ?? "Untitled.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        currentURL = url
        return writeCurrentDocument()
    }

    @discardableResult private func writeCurrentDocument() -> Bool {
        guard let url = currentURL else { return false }
        do {
            if url.pathExtension.lowercased() == "rtf" {
                let range = NSRange(location: 0, length: textView.string.utf16.count)
                guard let data = textView.rtf(from: range) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                try data.write(to: url, options: .atomic)
            } else {
                try textView.string.write(to: url, atomically: true, encoding: .utf8)
            }
            isDirty = false
            updateWindowTitle()
            return true
        } catch {
            presentError(title: "Couldn’t save that document", error: error)
            return false
        }
    }

    private func confirmProceedPastUnsavedChanges() -> Bool {
        guard isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "Save this writing first?"
        alert.informativeText = "Your current changes have not been saved."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Don’t Save")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return currentURL == nil ? saveDocumentAs(nil) : writeCurrentDocument()
        case .alertThirdButtonReturn:
            return true
        default:
            return false
        }
    }

    private func presentError(title: String, error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = title
        alert.runModal()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        confirmProceedPastUnsavedChanges()
    }
}

private struct EraMenuPalette {
    let panel: NSColor
    let hover: NSColor
    let text: NSColor
    let hoverText: NSColor
    let accent: NSColor
    let border: NSColor

    static func make(for theme: WritingTheme) -> EraMenuPalette {
        switch theme.id {
        case .calm:
            return EraMenuPalette(
                panel: NSColor(calibratedRed: 0.96, green: 0.90, blue: 0.78, alpha: 0.98),
                hover: NSColor(calibratedRed: 0.67, green: 0.50, blue: 0.29, alpha: 1),
                text: NSColor(calibratedRed: 0.18, green: 0.13, blue: 0.08, alpha: 1),
                hoverText: .white,
                accent: NSColor(calibratedRed: 0.43, green: 0.29, blue: 0.15, alpha: 1),
                border: NSColor(calibratedRed: 0.46, green: 0.34, blue: 0.21, alpha: 0.72)
            )
        case .mac1999:
            return EraMenuPalette(
                panel: NSColor(calibratedWhite: 0.83, alpha: 1),
                hover: NSColor(calibratedRed: 0.33, green: 0.34, blue: 0.47, alpha: 1),
                text: .black,
                hoverText: .white,
                accent: NSColor(calibratedRed: 0.25, green: 0.26, blue: 0.39, alpha: 1),
                border: NSColor(calibratedWhite: 0.23, alpha: 1)
            )
        case .system95:
            return EraMenuPalette(
                panel: NSColor(calibratedWhite: 0.76, alpha: 1),
                hover: NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.52, alpha: 1),
                text: .black,
                hoverText: .white,
                accent: NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.52, alpha: 1),
                border: NSColor(calibratedWhite: 0.18, alpha: 1)
            )
        case .dos:
            return EraMenuPalette(
                panel: NSColor(calibratedRed: 0.004, green: 0.024, blue: 0.015, alpha: 1),
                hover: NSColor(calibratedRed: 0.08, green: 0.27, blue: 0.14, alpha: 1),
                text: NSColor(calibratedRed: 0.34, green: 0.96, blue: 0.56, alpha: 1),
                hoverText: NSColor(calibratedRed: 0.72, green: 1, blue: 0.79, alpha: 1),
                accent: NSColor(calibratedRed: 0.34, green: 0.96, blue: 0.56, alpha: 1),
                border: NSColor(calibratedRed: 0.19, green: 0.70, blue: 0.38, alpha: 1)
            )
        case .typewriter:
            return EraMenuPalette(
                panel: NSColor(calibratedRed: 0.94, green: 0.87, blue: 0.71, alpha: 1),
                hover: NSColor(calibratedRed: 0.27, green: 0.14, blue: 0.065, alpha: 1),
                text: NSColor(calibratedRed: 0.17, green: 0.10, blue: 0.055, alpha: 1),
                hoverText: NSColor(calibratedRed: 0.98, green: 0.91, blue: 0.76, alpha: 1),
                accent: NSColor(calibratedRed: 0.42, green: 0.23, blue: 0.10, alpha: 1),
                border: NSColor(calibratedRed: 0.29, green: 0.16, blue: 0.075, alpha: 0.82)
            )
        case .library:
            return EraMenuPalette(
                panel: NSColor(calibratedRed: 0.95, green: 0.87, blue: 0.70, alpha: 1),
                hover: NSColor(calibratedRed: 0.48, green: 0.31, blue: 0.14, alpha: 1),
                text: NSColor(calibratedRed: 0.19, green: 0.115, blue: 0.060, alpha: 1),
                hoverText: NSColor(calibratedRed: 1, green: 0.95, blue: 0.82, alpha: 1),
                accent: NSColor(calibratedRed: 0.47, green: 0.27, blue: 0.09, alpha: 1),
                border: NSColor(calibratedRed: 0.43, green: 0.27, blue: 0.12, alpha: 0.82)
            )
        case .spaceAge:
            return EraMenuPalette(
                panel: NSColor(calibratedRed: 0.025, green: 0.09, blue: 0.12, alpha: 1),
                hover: NSColor(calibratedRed: 0.12, green: 0.32, blue: 0.34, alpha: 1),
                text: NSColor(calibratedRed: 1, green: 0.88, blue: 0.65, alpha: 1),
                hoverText: .white,
                accent: NSColor(calibratedRed: 0.96, green: 0.33, blue: 0.10, alpha: 1),
                border: NSColor(calibratedRed: 0.84, green: 0.49, blue: 0.20, alpha: 0.86)
            )
        case .cyberdeck:
            return EraMenuPalette(
                panel: NSColor(calibratedRed: 0.004, green: 0.018, blue: 0.052, alpha: 1),
                hover: NSColor(calibratedRed: 0.08, green: 0.035, blue: 0.16, alpha: 1),
                text: NSColor(calibratedRed: 0.39, green: 1, blue: 0.94, alpha: 1),
                hoverText: .white,
                accent: NSColor(calibratedRed: 1, green: 0.08, blue: 0.62, alpha: 1),
                border: NSColor(calibratedRed: 0.13, green: 0.82, blue: 0.92, alpha: 0.88)
            )
        case .hell:
            return EraMenuPalette(
                panel: NSColor(calibratedRed: 0.022, green: 0.005, blue: 0.007, alpha: 1),
                hover: NSColor(calibratedRed: 0.25, green: 0.018, blue: 0.012, alpha: 1),
                text: NSColor(calibratedRed: 0.91, green: 0.82, blue: 0.70, alpha: 1),
                hoverText: NSColor(calibratedRed: 1, green: 0.91, blue: 0.78, alpha: 1),
                accent: NSColor(calibratedRed: 0.76, green: 0.075, blue: 0.025, alpha: 1),
                border: NSColor(calibratedRed: 0.45, green: 0.035, blue: 0.022, alpha: 1)
            )
        case .liquidGlass:
            return EraMenuPalette(
                panel: NSColor(calibratedWhite: 1, alpha: 0.91),
                hover: NSColor(calibratedRed: 0.48, green: 0.64, blue: 1, alpha: 0.42),
                text: NSColor(calibratedWhite: 0.08, alpha: 1),
                hoverText: NSColor(calibratedWhite: 0.04, alpha: 1),
                accent: NSColor(calibratedRed: 0.20, green: 0.38, blue: 0.92, alpha: 1),
                border: NSColor(calibratedWhite: 1, alpha: 0.95)
            )
        }
    }
}

private final class EraMenuItemView: NSView {
    private static weak var activeHover: EraMenuItemView?
    private weak var item: NSMenuItem?
    private let theme: WritingTheme
    private let palette: EraMenuPalette
    private var tracking: NSTrackingArea?
    fileprivate var isHovered = false {
        didSet { needsDisplay = true }
    }
    var onInvoke: ((NSMenuItem) -> Void)?

    init(item: NSMenuItem, theme: WritingTheme, width: CGFloat) {
        self.item = item
        self.theme = theme
        self.palette = .make(for: theme)
        let height: CGFloat = theme.prefersPixelEdges ? 25 : (theme.id == .typewriter ? 31 : 29)
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let next = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(next)
        tracking = next
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if superview == nil { clearHover() }
    }

    override func mouseEntered(with event: NSEvent) {
        guard Self.activeHover !== self else { return }
        Self.activeHover?.isHovered = false
        Self.activeHover = self
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        clearHover()
    }

    override func mouseUp(with event: NSEvent) {
        guard let item, item.isEnabled else { return }
        clearHover()
        if let onInvoke {
            onInvoke(item)
            return
        }
        guard let action = item.action else { return }
        item.menu?.cancelTracking()
        _ = NSApp.sendAction(action, to: item.target, from: item)
    }

    private func clearHover() {
        isHovered = false
        if Self.activeHover === self { Self.activeHover = nil }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let item else { return }
        (isHovered ? palette.hover : palette.panel).setFill()
        bounds.fill()

        if theme.prefersPixelEdges {
            palette.border.setStroke()
            let edge = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
            edge.lineWidth = 1
            edge.stroke()
        } else if theme.id == .typewriter {
            NSColor(calibratedRed: 0.25, green: 0.14, blue: 0.07, alpha: 0.055).setFill()
            for x in stride(from: CGFloat(5), to: bounds.width, by: 17) {
                NSRect(x: x, y: CGFloat(Int(x) % 11), width: 1, height: 1).fill()
            }
        } else if theme.id == .cyberdeck {
            palette.accent.withAlphaComponent(isHovered ? 0.92 : 0.45).setFill()
            NSRect(x: 0, y: 0, width: 3, height: bounds.height).fill()
            NSRect(x: bounds.maxX - 1, y: 0, width: 1, height: bounds.height).fill()
        } else if theme.id == .hell {
            palette.accent.withAlphaComponent(isHovered ? 0.76 : 0.32).setFill()
            NSRect(x: 0, y: 0, width: 2, height: bounds.height).fill()
        }

        let font: NSFont
        if theme.prefersPixelEdges || theme.id == .cyberdeck {
            font = NSFont.monospacedSystemFont(ofSize: theme.prefersPixelEdges ? 13 : 12.5, weight: .medium)
        } else {
            font = theme.font(size: theme.id == .typewriter ? 14 : 13.5)
        }
        let foreground = (isHovered ? palette.hoverText : palette.text).withAlphaComponent(item.isEnabled ? 1 : 0.46)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: foreground]
        let titleSize = item.title.size(withAttributes: attributes)
        item.title.draw(at: NSPoint(x: 34, y: (bounds.height - titleSize.height) * 0.5), withAttributes: attributes)

        if item.state == .on {
            let mark = theme.id == .dos ? "◆" : (theme.id == .cyberdeck ? "▸" : "✓")
            let markAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: palette.accent]
            let markSize = mark.size(withAttributes: markAttributes)
            mark.draw(at: NSPoint(x: 12, y: (bounds.height - markSize.height) * 0.5), withAttributes: markAttributes)
        }

        if !item.keyEquivalent.isEmpty {
            let shortcut = "⌘" + item.keyEquivalent.uppercased()
            let keyAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular), .foregroundColor: foreground.withAlphaComponent(0.68)]
            let keySize = shortcut.size(withAttributes: keyAttributes)
            shortcut.draw(at: NSPoint(x: bounds.maxX - keySize.width - 14, y: (bounds.height - keySize.height) * 0.5), withAttributes: keyAttributes)
        }
    }
}

private final class EraMenuSeparatorView: NSView {
    private let theme: WritingTheme
    private let palette: EraMenuPalette

    init(theme: WritingTheme, width: CGFloat) {
        self.theme = theme
        self.palette = .make(for: theme)
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: theme.prefersPixelEdges ? 7 : 9))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        palette.panel.setFill()
        bounds.fill()
        palette.border.withAlphaComponent(0.70).setFill()
        NSRect(x: 12, y: bounds.midY, width: bounds.width - 24, height: theme.id == .dos ? 1 : 0.7).fill()
    }
}

private final class EraMenuPanelView: NSView {
    private let theme: WritingTheme
    private let palette: EraMenuPalette

    init(frame: NSRect, theme: WritingTheme) {
        self.theme = theme
        self.palette = .make(for: theme)
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func mouseDown(with event: NSEvent) {}

    override func draw(_ dirtyRect: NSRect) {
        palette.panel.setFill()
        bounds.fill()
        palette.border.setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 0.75, dy: 0.75))
        border.lineWidth = theme.prefersPixelEdges ? 2 : 1.5
        border.stroke()
        if theme.id == .dos {
            palette.accent.withAlphaComponent(0.06).setFill()
            for y in stride(from: CGFloat(2), to: bounds.height, by: 3) { NSRect(x: 1, y: y, width: bounds.width - 2, height: 1).fill() }
        }
    }
}

private final class EraMenuOverlay: NSView {
    var onDismiss: (() -> Void)?
    private let theme: WritingTheme
    private let anchor: NSPoint
    private let width: CGFloat = 286
    private weak var panel: EraMenuPanelView?
    private var retainedMenu: NSMenu?

    init(frame: NSRect, menu: NSMenu, theme: WritingTheme, anchor: NSPoint) {
        self.theme = theme
        self.anchor = anchor
        super.init(frame: frame)
        rebuild(with: menu)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func mouseDown(with event: NSEvent) { dismiss() }

    private func rowHeight(for item: NSMenuItem) -> CGFloat {
        if item.isSeparatorItem { return theme.prefersPixelEdges ? 7 : 9 }
        return theme.prefersPixelEdges ? 25 : (theme.id == .typewriter ? 31 : 29)
    }

    private func rebuild(with menu: NSMenu) {
        retainedMenu = menu
        panel?.removeFromSuperview()
        let height = menu.items.reduce(CGFloat(10)) { $0 + rowHeight(for: $1) }
        let x = min(max(8, anchor.x), max(8, bounds.width - width - 8))
        let below = anchor.y - height - 5
        let y = below >= 8 ? below : min(max(8, anchor.y + 7), max(8, bounds.height - height - 8))
        let nextPanel = EraMenuPanelView(frame: NSRect(x: x, y: y, width: width, height: height), theme: theme)
        nextPanel.autoresizingMask = []
        addSubview(nextPanel)
        panel = nextPanel

        var cursor = height - 5
        for item in menu.items {
            let itemHeight = rowHeight(for: item)
            cursor -= itemHeight
            if item.isSeparatorItem {
                let separator = EraMenuSeparatorView(theme: theme, width: width - 2)
                separator.frame.origin = NSPoint(x: 1, y: cursor)
                nextPanel.addSubview(separator)
            } else {
                let row = EraMenuItemView(item: item, theme: theme, width: width - 2)
                row.frame.origin = NSPoint(x: 1, y: cursor)
                row.onInvoke = { [weak self] selected in self?.activate(selected) }
                nextPanel.addSubview(row)
            }
        }
    }

    private func activate(_ item: NSMenuItem) {
        if let submenu = item.submenu {
            rebuild(with: submenu)
            return
        }
        guard let action = item.action else { return }
        let target = item.target
        dismiss()
        DispatchQueue.main.async { _ = NSApp.sendAction(action, to: target, from: item) }
    }

    private func dismiss() {
        removeFromSuperview()
        onDismiss?()
    }
}

private final class FontChooserOverlay: NSView, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    var onChoose: ((NSFont) -> Void)?
    var onDismiss: (() -> Void)?

    private let theme: WritingTheme
    private let palette: EraMenuPalette
    private let panel: EraMenuPanelView
    private let searchField = NSTextField()
    private let preview = NSTextField(labelWithString: "The next sentence begins here.")
    private let table = NSTableView()
    private let sizeSlider = NSSlider(value: 20, minValue: 11, maxValue: 48, target: nil, action: nil)
    private let sizeLabel = NSTextField(labelWithString: "")
    private var families: [String]
    private var filteredFamilies: [String]
    private var chosenFamily: String?

    init(frame: NSRect, theme: WritingTheme, currentSize: CGFloat, usesPersianPreview: Bool) {
        self.theme = theme
        self.palette = .make(for: theme)

        let installed = NSFontManager.shared.availableFontFamilies
        var ordered: [String] = []
        var seen = Set<String>()
        let contextualFamilies = usesPersianPreview
            ? ["Vazirmatn", "Noto Naskh Arabic", "Noto Sans Arabic", "Geeza Pro", "SF Arabic"]
            : []
        for family in theme.defaultFontNames + contextualFamilies + installed {
            let key = family.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            if !seen.contains(key) {
                seen.insert(key)
                ordered.append(family)
            }
        }
        self.families = ordered
        self.filteredFamilies = ordered
        self.chosenFamily = ordered.first
        self.panel = EraMenuPanelView(frame: .zero, theme: theme)
        super.init(frame: frame)

        let panelWidth = min(CGFloat(570), max(440, frame.width - 56))
        let panelHeight = min(CGFloat(470), max(380, frame.height - 48))
        panel.frame = NSRect(
            x: (frame.width - panelWidth) * 0.5,
            y: (frame.height - panelHeight) * 0.5,
            width: panelWidth,
            height: panelHeight
        )
        panel.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        addSubview(panel)

        let pixel = theme.prefersPixelEdges
        let titleFont = pixel ? NSFont.monospacedSystemFont(ofSize: 16, weight: .bold) : theme.font(size: 17)
        let title = NSTextField(labelWithString: theme.id == .dos ? "FONT DIRECTORY" : "Choose a writing font")
        title.font = titleFont
        title.textColor = palette.text
        title.frame = NSRect(x: 20, y: panelHeight - 43, width: panelWidth - 40, height: 24)
        panel.addSubview(title)

        preview.alignment = .center
        preview.lineBreakMode = .byTruncatingTail
        preview.textColor = palette.text
        preview.stringValue = usesPersianPreview ? "جمله‌ی بعدی از اینجا آغاز می‌شود." : "The next sentence begins here."
        preview.alignment = usesPersianPreview ? .right : .center
        preview.frame = NSRect(x: 20, y: panelHeight - 91, width: panelWidth - 40, height: 34)
        panel.addSubview(preview)

        searchField.placeholderString = "Search installed fonts"
        searchField.delegate = self
        searchField.font = pixel ? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular) : NSFont.systemFont(ofSize: 13)
        searchField.textColor = palette.text
        searchField.drawsBackground = true
        searchField.backgroundColor = palette.panel.blended(withFraction: 0.10, of: palette.hover) ?? palette.panel
        searchField.isBordered = true
        searchField.focusRingType = .none
        searchField.frame = NSRect(x: 20, y: panelHeight - 130, width: panelWidth - 40, height: 27)
        panel.addSubview(searchField)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("font"))
        column.width = panelWidth - 56
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 30
        table.intercellSpacing = NSSize(width: 0, height: 1)
        table.backgroundColor = palette.panel
        table.selectionHighlightStyle = .none
        table.delegate = self
        table.dataSource = self
        table.target = self
        table.doubleAction = #selector(useSelectedFont)

        let scroll = NSScrollView(frame: NSRect(x: 20, y: 72, width: panelWidth - 40, height: panelHeight - 215))
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = palette.panel
        scroll.borderType = pixel ? .lineBorder : .noBorder
        panel.addSubview(scroll)

        sizeSlider.doubleValue = Double(max(11, min(48, currentSize)))
        sizeSlider.target = self
        sizeSlider.action = #selector(sizeChanged(_:))
        sizeSlider.isContinuous = true
        sizeSlider.frame = NSRect(x: 20, y: 27, width: 145, height: 24)
        panel.addSubview(sizeSlider)

        sizeLabel.textColor = palette.text
        sizeLabel.font = pixel ? NSFont.monospacedSystemFont(ofSize: 12, weight: .medium) : NSFont.systemFont(ofSize: 12, weight: .medium)
        sizeLabel.frame = NSRect(x: 173, y: 29, width: 70, height: 20)
        panel.addSubview(sizeLabel)

        let cancel = makeButton(title: "Cancel", action: #selector(cancelPressed))
        cancel.frame = NSRect(x: panelWidth - 210, y: 22, width: 82, height: 30)
        panel.addSubview(cancel)
        let use = makeButton(title: theme.id == .dos ? "USE FONT" : "Use Font", action: #selector(useSelectedFont))
        use.frame = NSRect(x: panelWidth - 120, y: 22, width: 100, height: 30)
        panel.addSubview(use)

        table.reloadData()
        if !filteredFamilies.isEmpty {
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        updatePreview()
        updateSizeLabel()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self.searchField)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if !panel.frame.contains(point) { dismiss() }
    }

    private func makeButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = theme.prefersPixelEdges ? .regularSquare : .texturedRounded
        button.bezelColor = palette.hover
        button.contentTintColor = palette.hoverText
        let font = theme.prefersPixelEdges ? NSFont.monospacedSystemFont(ofSize: 12, weight: .bold) : theme.font(size: 12)
        button.font = font
        button.attributedTitle = NSAttributedString(string: title, attributes: [.font: font, .foregroundColor: palette.hoverText])
        return button
    }

    private func font(for family: String, size: CGFloat) -> NSFont {
        NSFont(name: family, size: size)
            ?? NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size)
            ?? NSFont.systemFont(ofSize: size)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { filteredFamilies.count }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        EraFontRowView(palette: palette)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard filteredFamilies.indices.contains(row) else { return nil }
        let family = filteredFamilies[row]
        let label = NSTextField(labelWithString: family)
        label.font = font(for: family, size: 15)
        label.textColor = palette.text
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: 10, y: 4, width: max(80, tableView.bounds.width - 20), height: 22)
        return label
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = table.selectedRow
        if filteredFamilies.indices.contains(row) { chosenFamily = filteredFamilies[row] }
        updatePreview()
    }

    func controlTextDidChange(_ obj: Notification) {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        filteredFamilies = query.isEmpty ? families : families.filter {
            $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
        table.reloadData()
        if !filteredFamilies.isEmpty {
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            chosenFamily = filteredFamilies[0]
        } else {
            chosenFamily = nil
        }
        updatePreview()
    }

    @objc private func sizeChanged(_ sender: NSSlider) {
        updatePreview()
        updateSizeLabel()
    }

    private func updatePreview() {
        guard let chosenFamily else { return }
        preview.font = font(for: chosenFamily, size: CGFloat(sizeSlider.doubleValue))
    }

    private func updateSizeLabel() {
        sizeLabel.stringValue = "\(Int(sizeSlider.doubleValue)) pt"
    }

    @objc private func useSelectedFont() {
        guard let chosenFamily else { return }
        onChoose?(font(for: chosenFamily, size: CGFloat(sizeSlider.doubleValue)))
        dismiss()
    }

    @objc private func cancelPressed() { dismiss() }

    private func dismiss() {
        removeFromSuperview()
        onDismiss?()
    }
}

private final class EraFontRowView: NSTableRowView {
    private let palette: EraMenuPalette

    init(palette: EraMenuPalette) {
        self.palette = palette
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func drawSelection(in dirtyRect: NSRect) {
        palette.hover.withAlphaComponent(0.82).setFill()
        bounds.fill()
    }

    override func drawBackground(in dirtyRect: NSRect) {
        palette.panel.setFill()
        bounds.fill()
    }
}
