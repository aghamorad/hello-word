import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = MainWindowController()
        mainWindowController = controller
        buildMainMenu(target: controller.editorController)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { mainWindowController?.showWindow(nil) }
        return true
    }

    private func buildMainMenu(target: MainViewController) {
        let main = NSMenu()
        NSApp.mainMenu = main

        let appMenu = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        main.addItem(appItem)
        appMenu.addItem(withTitle: "About Hello, Word", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        // A nil target sends this through the responder chain to the editor, so
        // the menu reaches the same card the version stamp does.
        appMenu.addItem(withTitle: "Check for Updates…", action: #selector(MainViewController.showUpdateCard(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Hello, Word", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Hello, Word", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let file = NSMenu(title: "File")
        addMenu(named: "File", menu: file, to: main)
        file.addItem(item("New", action: #selector(MainViewController.newDocument(_:)), key: "n", target: target))
        file.addItem(item("Open…", action: #selector(MainViewController.openDocument(_:)), key: "o", target: target))
        file.addItem(.separator())
        file.addItem(item("Save", action: #selector(MainViewController.saveDocument(_:)), key: "s", target: target))
        let saveAs = item("Save As…", action: #selector(MainViewController.saveDocumentAs(_:)), key: "S", target: target)
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        file.addItem(saveAs)
        file.addItem(.separator())
        file.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let edit = NSMenu(title: "Edit")
        addMenu(named: "Edit", menu: edit, to: main)
        edit.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        edit.addItem(.separator())
        edit.addItem(findItem("Find…", action: .showFindInterface, key: "f"))
        edit.addItem(findItem("Find and Replace…", action: .showReplaceInterface, key: ""))
        edit.addItem(findItem("Find Next", action: .nextMatch, key: "g"))
        let previous = findItem("Find Previous", action: .previousMatch, key: "G")
        previous.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(previous)
        edit.addItem(findItem("Use Selection for Find", action: .setSearchString, key: "e"))
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: "Check Spelling", action: #selector(NSTextView.checkSpelling(_:)), keyEquivalent: ":"))

        let format = NSMenu(title: "Format")
        addMenu(named: "Format", menu: format, to: main)
        format.addItem(item("Choose Font…", action: #selector(MainViewController.showFontPanel(_:)), key: "t", target: target))
        format.addItem(.separator())
        let bold = NSMenuItem(title: "Bold", action: #selector(NSFontManager.addFontTrait(_:)), keyEquivalent: "b")
        bold.target = NSFontManager.shared
        bold.tag = Int(NSFontTraitMask.boldFontMask.rawValue)
        format.addItem(bold)
        let italic = NSMenuItem(title: "Italic", action: #selector(NSFontManager.addFontTrait(_:)), keyEquivalent: "i")
        italic.target = NSFontManager.shared
        italic.tag = Int(NSFontTraitMask.italicFontMask.rawValue)
        format.addItem(italic)
        format.addItem(NSMenuItem(title: "Underline", action: #selector(NSTextView.underline(_:)), keyEquivalent: "u"))
        format.addItem(.separator())
        let footnote = item("Insert Footnote", action: #selector(MainViewController.insertFootnote(_:)), key: "f", target: target)
        footnote.keyEquivalentModifierMask = [.command, .option]
        format.addItem(footnote)

        let directionMenu = NSMenu(title: "Paragraph Direction")
        directionMenu.addItem(item("Right to Left — Persian", action: #selector(MainViewController.setParagraphRightToLeft(_:)), key: "", target: target))
        directionMenu.addItem(item("Left to Right — English", action: #selector(MainViewController.setParagraphLeftToRight(_:)), key: "", target: target))
        let directionItem = NSMenuItem(title: "Paragraph Direction", action: nil, keyEquivalent: "")
        directionItem.submenu = directionMenu
        format.addItem(directionItem)

        let worlds = NSMenu(title: "World")
        addMenu(named: "World", menu: worlds, to: main)
        for (index, theme) in WritingTheme.all.enumerated() {
            let themeItem = item(theme.name, action: #selector(MainViewController.setThemeFromMenu(_:)), key: index < 5 ? String(index + 1) : "", target: target)
            themeItem.tag = index
            themeItem.keyEquivalentModifierMask = [.command, .option]
            worlds.addItem(themeItem)
        }

        let sound = NSMenu(title: "Sound")
        addMenu(named: "Sound", menu: sound, to: main)
        sound.addItem(item("Typing Sounds", action: #selector(MainViewController.toggleTypingSounds(_:)), key: "k", target: target))
        sound.addItem(item("Loop Music", action: #selector(MainViewController.toggleMusic(_:)), key: "", target: target))
        sound.addItem(.separator())
        sound.addItem(item("Open This World’s Music Folder…", action: #selector(MainViewController.openMusicFolder(_:)), key: "", target: target))

        let correction = NSMenu(title: "Correction")
        addMenu(named: "Correction", menu: correction, to: main)
        for mode in CorrectionMode.allCases {
            let modeItem = item(mode.title, action: #selector(MainViewController.setCorrectionFromMenu(_:)), key: "", target: target)
            modeItem.tag = mode.rawValue
            correction.addItem(modeItem)
        }

        let viewMenu = NSMenu(title: "View")
        addMenu(named: "View", menu: viewMenu, to: main)
        viewMenu.addItem(item("Show or Hide Controls", action: #selector(MainViewController.toggleInterface(_:)), key: "\\", target: target))
        let fullScreen = item("Enter Full Screen", action: #selector(MainViewController.enterFullScreen(_:)), key: "f", target: target)
        fullScreen.keyEquivalentModifierMask = [.command, .control]
        viewMenu.addItem(fullScreen)

        let windowMenu = NSMenu(title: "Window")
        addMenu(named: "Window", menu: windowMenu, to: main)
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu
    }

    private func addMenu(named name: String, menu: NSMenu, to main: NSMenu) {
        let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
        item.submenu = menu
        main.addItem(item)
    }

    private func item(_ title: String, action: Selector, key: String, target: AnyObject) -> NSMenuItem {
        let result = NSMenuItem(title: title, action: action, keyEquivalent: key)
        result.target = target
        return result
    }

    private func findItem(_ title: String, action: NSTextFinder.Action, key: String) -> NSMenuItem {
        let result = NSMenuItem(
            title: title,
            action: #selector(NSTextView.performTextFinderAction(_:)),
            keyEquivalent: key
        )
        result.tag = Int(action.rawValue)
        // A nil target sends the action through the responder chain to the active
        // editor. This keeps Find working even after a document or room changes.
        result.target = nil
        return result
    }
}
