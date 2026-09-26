import AppKit

/// Is this a stale cut of Hello, Word?
///
/// One question to GitHub when the writing room first appears: what is the
/// newest release? If it is newer than the version this build was cut at, the
/// version stamp at the end of the control strip turns amber and says so.
///
/// Nothing else happens. No window opens on its own, nothing is downloaded, and
/// nothing is installed. This room exists to get out of the way, so a notice
/// that interrupted a sentence would be worse than the stale build it warned
/// about — the answer only ever decorates a corner the writer is already
/// looking at.
///
/// Failure is the ordinary case, not the exception: no network, a firewall, or
/// GitHub throttled to a crawl all land on `.unknown`, and the app carries on
/// exactly as it did before. There is deliberately no error a writer can see.
/// "We could not check" is our problem, not theirs.
///
/// The build's version is read from the bundle, which is the number
/// `Scripts/build-app.sh` ships. The checker never guesses it: a build that
/// cannot say what version it is says nothing at all rather than calling itself
/// out of date.
@MainActor
final class UpdateChecker {
    enum State: Equatable {
        case idle, checking, current, stale, unknown
    }

    static let repository = "aghamorad/hello-word"
    private static let api = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    private static let releases = URL(string: "https://github.com/\(repository)/releases/latest")!

    /// GitHub answers, or it does not; a throttled connection can leave the
    /// request open for minutes. Nothing is waiting on the answer, so cut it
    /// loose and call that "unknown" rather than letting a check sit in flight.
    private static let timeout: TimeInterval = 9

    private(set) var state: State = .idle
    private(set) var latest: String?
    private(set) var releaseURL: URL?

    /// Called on the main thread whenever the answer changes.
    var onChange: (() -> Void)?

    private var inFlight: Task<Void, Never>?

    /// The version this build was cut at, or nil when there is no bundle to ask.
    var version: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var hasUpdate: Bool { state == .stale }

    /// The line at the end of the control strip. Before the check answers it is
    /// the plain version stamp; it only ever becomes a notice once it knows
    /// something.
    var stamp: String {
        guard let version else { return "HELLO, WORD" }
        if let latest, hasUpdate { return "v\(latest) IS OUT" }
        return "v\(version)"
    }

    func check() {
        guard inFlight == nil else { return }

        // Without a version of our own there is nothing honest to compare, so
        // the check is skipped rather than run and misread.
        guard let version else {
            state = .unknown
            publish()
            return
        }

        state = .checking
        publish()

        inFlight = Task { [weak self] in
            guard let self else { return }
            defer { inFlight = nil }
            do {
                var request = URLRequest(url: Self.api, timeoutInterval: Self.timeout)
                // The API's own media type: it is the documented way to ask, and
                // it keeps the response on the versioned shape.
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.cachePolicy = .reloadIgnoringLocalCacheData

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = object["tag_name"] as? String else {
                    throw URLError(.cannotParseResponse)
                }

                // The tag arrives dressed as `v0.5`, and every string that shows
                // it writes its own `v` in front. Keep the number here so the
                // copy owns the prefix and the two cannot double up.
                let released = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                latest = released
                if let html = object["html_url"] as? String, let url = URL(string: html) {
                    releaseURL = url
                }
                state = Self.isNewer(released, than: version) ? .stale : .current
            } catch {
                // Deliberately quiet. The writer was not doing anything wrong and
                // the room still works; a failure notice would be noise.
                state = .unknown
            }
            publish()
        }
    }

    func openRelease() {
        NSWorkspace.shared.open(releaseURL ?? Self.releases)
    }

    private func publish() {
        onChange?()
    }

    /// `0.5` and `v0.5` are the same number, and a tag carrying more parts than
    /// we expect compares on the parts it has rather than throwing.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = parts(candidate), b = parts(current)
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0
            let y = index < b.count ? b[index] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func parts(_ value: String) -> [Int] {
        let bare = value.hasPrefix("v") || value.hasPrefix("V") ? String(value.dropFirst()) : value
        return bare.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }
}

// MARK: - The card

/// Reached only by clicking the stamp or choosing "Check for Updates…", and
/// never opened on its own: a card that threw itself over the room on launch
/// would be the app interrupting a sentence to talk about itself.
@MainActor
final class UpdateCardController: NSViewController {
    private let updates: UpdateChecker

    private let titleLabel = NSTextField(labelWithString: "UPDATES")
    private let captionLabel = NSTextField(labelWithString: "Version")
    private let versionLabel = NSTextField(labelWithString: "")
    private let sentenceLabel = NSTextField(wrappingLabelWithString: "")
    private let primaryButton = NSButton()
    private let closeButton = NSButton()

    private static let width: CGFloat = 470
    private static let inset: CGFloat = 18

    init(updates: UpdateChecker) {
        self.updates = updates
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let root = NSVisualEffectView()
        root.material = .hudWindow
        root.blendingMode = .behindWindow
        root.state = .active
        root.wantsLayer = true

        titleLabel.font = .systemFont(ofSize: 10, weight: .bold)
        titleLabel.textColor = .secondaryLabelColor

        captionLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        captionLabel.alignment = .right
        captionLabel.setContentHuggingPriority(.required, for: .horizontal)

        versionLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)

        sentenceLabel.font = .systemFont(ofSize: 12)
        sentenceLabel.textColor = .secondaryLabelColor
        sentenceLabel.preferredMaxLayoutWidth = Self.width - Self.inset * 2

        primaryButton.bezelStyle = .rounded
        primaryButton.target = self
        primaryButton.action = #selector(primaryTapped(_:))
        primaryButton.keyEquivalent = "\r"

        closeButton.title = "Close"
        closeButton.bezelStyle = .rounded
        closeButton.target = self
        closeButton.action = #selector(closeTapped(_:))
        closeButton.keyEquivalent = "\u{1b}"

        let versionRow = NSStackView(views: [captionLabel, versionLabel])
        versionRow.orientation = .horizontal
        versionRow.alignment = .firstBaseline

        let buttonRow = NSStackView(views: [primaryButton, closeButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 10

        let stack = NSStackView(views: [titleLabel, versionRow, sentenceLabel, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: Self.inset, left: Self.inset, bottom: Self.inset, right: Self.inset)
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        let content = Self.width - Self.inset * 2
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            root.widthAnchor.constraint(equalToConstant: Self.width),
            captionLabel.widthAnchor.constraint(equalToConstant: 62),
            sentenceLabel.widthAnchor.constraint(equalToConstant: content),
            buttonRow.widthAnchor.constraint(equalToConstant: content)
        ])

        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        refresh()
    }

    /// Reads the checker's current answer. Called on appearance and again by the
    /// editor whenever the answer changes, so a card left open while a check
    /// lands is never showing yesterday's sentence.
    func refresh() {
        versionLabel.stringValue = updates.version.map { "v\($0)" } ?? "unknown"
        sentenceLabel.stringValue = sentence

        if updates.hasUpdate {
            primaryButton.title = "Get v\(updates.latest ?? "")"
            primaryButton.isEnabled = true
        } else {
            switch updates.state {
            case .checking:
                primaryButton.title = "Checking…"
                primaryButton.isEnabled = false
            case .unknown:
                primaryButton.title = "Try again"
                primaryButton.isEnabled = true
            default:
                primaryButton.title = "Check for updates"
                primaryButton.isEnabled = true
            }
        }
    }

    /// What the check found, said plainly. An unanswered check is never dressed
    /// up as good news: "could not reach it" is its own sentence, and the room
    /// runs the same either way.
    private var sentence: String {
        switch updates.state {
        case .idle:
            return "Hello, Word has not asked yet. Checking reaches GitHub once; nothing is downloaded and nothing is installed."
        case .checking:
            return "Asking GitHub which release is newest…"
        case .current:
            return "Newest cut. You already have it — whatever is wrong is not our bug."
        case .stale:
            return "A newer release is out — v\(updates.latest ?? ""). You are running v\(updates.version ?? "unknown")."
        case .unknown:
            return "Could not reach GitHub. The room works the same either way, and releases are listed on the project page."
        }
    }

    @objc private func primaryTapped(_ sender: Any?) {
        if updates.hasUpdate {
            updates.openRelease()
        } else {
            updates.check()
        }
    }

    @objc private func closeTapped(_ sender: Any?) {
        dismiss(self)
    }
}
