# How Hello, Word fits together

Hello, Word is a native AppKit application. There is no embedded browser, Electron runtime, web server or account layer. The visual worlds are drawn by the app, the editor is an `NSTextView`, the ambience uses `AVFoundation`, and documents use Apple's native text and RTF machinery.

## From launch to writing

1. `main.swift` starts `NSApplication` and installs `AppDelegate`.
2. `AppDelegate` constructs the native menu bar and opens `MainWindowController`.
3. `MainWindowController` creates one native window, configures full screen, and hosts `MainViewController`.
4. `MainViewController` layers `BackdropView`, the transparent `FocusTextView`, and the controls. It briefly presents the splash card, then returns focus to the editor.

## How a world changes

`WritingTheme` is the shared definition of a room: its colors, type, insertion color, spacing, control character, sound identity and music folder. When the room changes, `MainViewController` applies that definition to the editor and controls; `BackdropView` redraws the environment; `TypingAudioController` selects the matching key profile; and `MusicLibrary` finds the matching user track or bundled placeholder.

Most environments are code-drawn. Typewriter, Midnight Library and Hell use compact original painterly backdrops rendered aspect-fill, with their interactive controls and writing surfaces remaining native AppKit layers above the art. This keeps the app relatively compact, lets the rooms fill any window, and allows Liquid Glass to remain genuinely transparent.

## How writing stays native

`FocusTextView` subclasses `NSTextView`, so selection, undo, Find, spelling, grammar, RTF links and the macOS text system continue to work. Its enclosing scroll view and text container are deliberately transparent. The themed in-world font chooser reads the system's installed font families without opening a separate native panel. The writing-width slider adjusts the text container and its maximum is capped per world so text cannot escape a depicted sheet, monitor or console.

`MainViewController` watches the current paragraph after edits. A strong Arabic-script character makes the paragraph RTL and right-aligned; Arabic-script runs receive an available Persian-capable font. English paragraphs remain LTR. Manual direction commands override the automatic choice.

## How correction works

There are two local correction layers:

- `CorrectionEngine` uses Apple's spelling and grammar services plus a conservative table of common errors.
- `HarperCorrectionService` invokes the bundled Harper command-line helper after a short pause, parses its JSON suggestions, and applies only a single unambiguous contextual replacement automatically.

Predominantly Persian paragraphs skip the English Harper pass. The helper runs as a local child process and receives only the paragraph being checked.

## How footnotes work

Each footnote receives a stable internal number. The source marker and note label are attributed links with matching `helloword-footnote://` URLs. Clicking either link finds the opposite URL in the text storage and scrolls there.

The source paragraph decides localization. LTR sources use `Footnotes` and Western numerals. RTL sources use `پانویس`, Persian numerals, right alignment and a Persian-capable font. The stored URL retains Western digits so navigation stays language-independent.

## How sound stays small

`TypingAudioController` synthesizes short key events at runtime instead of shipping many audio samples. Return, space and ordinary keys can therefore differ without turning the app into a large sound library.

The ten ambient beds are compact AAC files. `MusicLibrary` first checks the current world's folder under Application Support; when that is empty it falls back to the corresponding bundled track.

## Document lifecycle

Open and Save use native panels. Plain text and RTF are supported directly. Once a document has a URL, changes are autosaved after a delay. An unnamed document is kept only in memory until the writer explicitly saves it. The application has no network sync or private document database.
