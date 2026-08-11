import AppKit
import AVFoundation

final class MusicLibrary: NSObject, AVAudioPlayerDelegate {
    var isEnabled = false {
        didSet { refreshPlayback() }
    }
    var volume: Float = 0.24 {
        didSet { player?.volume = volume }
    }
    private(set) var currentTheme: ThemeID = .calm
    private(set) var currentTrackName: String?

    private var player: AVAudioPlayer?
    private let supportedExtensions = Set(["mp3", "m4a", "aac", "wav", "aif", "aiff", "caf"])

    override init() {
        super.init()
        createMusicFolders()
    }

    var rootURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Hello, Word", isDirectory: true)
            .appendingPathComponent("Music", isDirectory: true)
    }

    func folder(for theme: ThemeID) -> URL {
        rootURL.appendingPathComponent(theme.rawValue, isDirectory: true)
    }

    func activate(_ theme: ThemeID) {
        currentTheme = theme
        refreshPlayback()
    }

    func openCurrentThemeFolder() {
        createMusicFolders()
        NSWorkspace.shared.open(folder(for: currentTheme))
    }

    private func createMusicFolders() {
        do {
            try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
            for theme in ThemeID.allCases {
                try FileManager.default.createDirectory(at: folder(for: theme), withIntermediateDirectories: true)
            }
        } catch {
            NSLog("Hello, Word could not create its music folders: \(error.localizedDescription)")
        }
    }

    private func refreshPlayback() {
        player?.stop()
        player = nil
        currentTrackName = nil
        guard isEnabled else { return }

        let directory = folder(for: currentTheme)
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        let userTrack = urls
            .filter({ supportedExtensions.contains($0.pathExtension.lowercased()) })
            .sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending })
            .first
        let placeholder = Bundle.main.resourceURL?
            .appendingPathComponent("Placeholder Music", isDirectory: true)
            .appendingPathComponent("\(currentTheme.rawValue).m4a")
        let track = userTrack ?? placeholder
        guard let track, FileManager.default.fileExists(atPath: track.path) else { return }

        do {
            let audio = try AVAudioPlayer(contentsOf: track)
            audio.numberOfLoops = -1
            audio.volume = volume
            audio.delegate = self
            audio.prepareToPlay()
            audio.play()
            player = audio
            currentTrackName = track.deletingPathExtension().lastPathComponent
        } catch {
            NSLog("Hello, Word could not play \(track.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
