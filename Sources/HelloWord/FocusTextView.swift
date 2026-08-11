import AppKit

enum TypingKey: Hashable {
    case character
    case space
    case returnKey
    case delete
}

final class FocusTextView: NSTextView {
    var onTypingKey: ((TypingKey) -> Void)?
    var correctionEngine: LocalCorrectionEngine?

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) || flags.contains(.control) {
            super.keyDown(with: event)
            return
        }

        let key: TypingKey
        switch event.keyCode {
        case 36, 76:
            key = .returnKey
        case 51, 117:
            key = .delete
        default:
            key = event.characters == " " ? .space : .character
        }

        if !event.isARepeat { onTypingKey?(key) }
        super.keyDown(with: event)

        if key == .space || key == .returnKey {
            applyLocalCorrectionBeforeCursor()
        }
    }

    private func applyLocalCorrectionBeforeCursor() {
        guard let correctionEngine, correctionEngine.mode != .off else { return }
        let cursor = selectedRange().location
        guard cursor > 1 else { return }

        let source = string as NSString
        var end = cursor - 1
        let whitespace = CharacterSet.whitespacesAndNewlines
        while end > 0 {
            let scalar = source.character(at: end)
            guard UnicodeScalar(scalar).map({ whitespace.contains($0) }) == true else { break }
            end -= 1
        }

        var start = end
        let letters = CharacterSet.letters.union(CharacterSet(charactersIn: "'’"))
        while start > 0 {
            let scalar = source.character(at: start - 1)
            guard UnicodeScalar(scalar).map({ letters.contains($0) }) == true else { break }
            start -= 1
        }

        let range = NSRange(location: start, length: end - start + 1)
        guard range.length > 0 else { return }
        let word = source.substring(with: range)
        guard let replacement = correctionEngine.correction(for: word), replacement != word else { return }

        if shouldChangeText(in: range, replacementString: replacement) {
            textStorage?.replaceCharacters(in: range, with: replacement)
            didChangeText()
        }
    }
}
