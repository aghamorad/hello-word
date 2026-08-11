import AppKit

final class MainWindowController: NSWindowController {
    let editorController: MainViewController

    init() {
        editorController = MainViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = editorController
        window.title = "Untitled — Hello, Word"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 700, height: 520)
        window.collectionBehavior = [.fullScreenPrimary]
        window.setFrameAutosaveName("HelloWordMainWindow")
        window.center()
        window.delegate = editorController
        super.init(window: window)
        shouldCascadeWindows = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
