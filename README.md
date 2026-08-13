# Hello, Word

<p align="center">
  <img src="Resources/AppIcon-1024.png" width="220" alt="Hello, Word — a retro Bondi-era Mac writing icon">
</p>

<p align="center"><strong>A small, native macOS writing room built to make the rest of the computer disappear.</strong></p>

## Why I made this

I am a writer and researcher, and I have always leaned toward simpler apps—apps that do less in the ordinary sense, perhaps, because the one thing I need them to do is rather enormous: let me disappear into the world of writing.

There used to be an app called OmmWriter, which has not been meaningfully updated in what feels like centuries, and I kept thinking about what a new version of that basic idea might become: full-screen writing environments instead of a blank page floating over a decorative background; music and typing sounds that belong to each world; controls that take on the character of the room and then get out of the way; good local correction; Persian as a real writing language rather than an afterthought; and enough practical word-processing machinery that one could, if sufficiently mad, write academic work in it too.

I should say that I am in no way a coder. I am not even a vibe coder. I am just a random guy who wanted to make the apps he wished existed on his computer in roughly the same way he writes the books he wishes existed in the world. Codex has, however, become rather powerful, and so I thought: well, perhaps I could ask my robot friend to make this one.

And so it did.

I really like it. I hope you do too.

## Download

The simplest route is the newest file on the [Releases](../../releases) page. Download the Apple-silicon archive, open it, and move **Hello, Word.app** into Applications.

| Mac | Download |
|---|---|
| Apple silicon — M1, M2, M3, M4 and later | `Hello-Word-v0.5-macOS-Apple-Silicon.zip` |

This preview is Apple-silicon only and requires macOS 13 or later. It is ad-hoc signed rather than Apple-notarized, so macOS may ask you to Control-click the app and choose **Open** the first time. The app does not need an account and does not upload your writing.

## What we tried to build

Hello, Word is deliberately small in its visible behavior. You open it, choose a world, and write. Beneath that simplicity are a few principles:

- **The room is the interface.** There is no permanent white rectangle pretending to be immersion. Every environment occupies the window, and in full screen it occupies the display.
- **The writing boundary should be felt, not stared at.** A width control lets you move from a narrow column to an almost room-wide field, but it stops at the actual paper or screen in worlds that have one. The boundary disappears when you return to the text.
- **Controls should belong to their world.** DOS controls look like terminal controls; the 1999 Macintosh room behaves like a complete platinum-era writing machine; the typewriter is paper, platen, wood and metal. The controls fade when they are no longer needed.
- **Sound should support attention.** Each world has its own keyboard voice and a quiet, seamless ambient bed. Both can be turned off instantly, and the bundled music can be replaced with your own.
- **Language is part of the writing surface.** Persian paragraphs automatically become right-to-left, use an appropriate installed Persian font, and can create properly RTL **پانویس** entries with Persian numerals.
- **Correction should be private and useful.** Contextual English correction runs locally through Harper. Ordinary macOS spelling and grammar remain available underneath it.

## The ten writing worlds

| World | What it is | What changes when you enter it |
|---|---|---|
| **Still** | A misted lake before dawn, with the shore and distant hills dissolving at the edges of a quiet writing field. | Soft neutral typography, quiet keys and a restrained ambient bed that never fights the lower lines of text. |
| **Macintosh 1999** | A complete platinum-era Mac writing machine. | Pixel details, period controls, classic computer-key sounds and warmer screen tones. |
| **System 95** | A maximised mid-1990s PC desktop and writing window. | Squarer controls, system-grey surfaces and a distinct PC keyboard profile. |
| **DOS Midnight** | The terminal itself rather than a terminal pasted onto a background. | Green phosphor text, scanlines, monospaced type and terse terminal controls. |
| **Typewriter** | A solitary Havana writing room rendered in measured mid-century realism, with a level, front-facing sheet held by platen, wood and metal. | The writing width and vertical editor bounds stay inside the real paper; keys are mechanical, while Return performs a lever, carriage sweep, ratchet and platen stop rather than a stray electronic bell. |
| **Midnight Library** | A luminous two-storey reading room of pale honey wood, curving shelves and quiet architectural depth. | Dark bookish typography, warm paper-and-oak controls, lamplight and an unusually restrained room tone. |
| **Space Age 1968** | An orbital word deck above a planetary horizon. | Console-like controls, analog-futurist color and slowly moving harmonic sound. |
| **Cyberdeck 2088** | A rain-dark neon city wired into the page. | Cyan/magenta instrumentation, a distant skyline, hard readable mono type, cybernetic keys and a submerged analog pulse. |
| **Hell** | A grave, painterly underworld of Pandemonium, black architecture, ember-lit stone and immeasurable depth. | Bone-colored text, low iron and cavern-din keystrokes, abyssal ambience, and an unnervingly calm road through damnation. Writing is hell; this room merely admits it. |
| **Liquid Glass** | The actual desktop behind the app, visible through native macOS translucency. | A full-opacity starting point, then a clear-to-tinted slider, reflection, edge glints and a writing surface that genuinely shows what is behind it. |

The period interfaces are functional. In **Macintosh 1999**, the in-world File, Edit, Format, World and Sound labels open real menus. In **System 95**, File, Edit, Search, Help, Start and the drawn window controls work. In **DOS Midnight**, F1 Help, F2 Save, F3 World and Esc Hide Controls can be clicked.

## The writing controls

The controls appear when the pointer moves and fade when writing resumes.

- **World selector** changes the entire environment, not merely the wallpaper.
- **Full screen** enters or leaves a borderless writing space; `Control–Command–F` works too.
- **Writing width** continuously adjusts how much of the room the text may occupy and cannot run beyond a depicted sheet, monitor or console.
- **Font** opens a themed chooser inside the current world, with search, bilingual English/Persian preview and every compatible font installed on the Mac.
- **A− / A+** changes the writing size without opening a formatting panel.
- **Typing sounds** and **music** are independent toggles.
- **Music folder** opens the folder for the current world so its ambient track can be replaced.
- **Correction selector** moves among offline contextual correction, balanced Apple correction, conservative enhanced correction, and completely off.
- **¹ footnote** inserts a linked reference and moves the cursor to its matching note.
- **Liquid Glass tint** appears only in the glass world and moves from genuinely clear to more private and tinted.

## Find and replace

`Command–F` opens the native macOS Find interface. **Edit → Find and Replace…** reveals replacement controls; **Find Next**, **Find Previous**, and **Use Selection for Find** are also available. The same commands appear inside the clickable Macintosh 1999 and System 95 menus, because a writing app without Find is, honestly, absurd.

## Autocorrection, without sending the page away

The default **Hello, Word Context — Offline** mode bundles [Harper](https://github.com/Automattic/harper), a privacy-first English grammar engine. Hello, Word waits until the writer pauses, checks the current paragraph locally, and automatically applies only a single unambiguous repair. This catches contextual mistakes—`could of`, for example—that ordinary spelling dictionaries do not understand.

The aim is not to pretend that a first independent build has somehow recreated every editorial judgment in Microsoft Word. The aim is more honest: make correction meaningfully better than the native baseline while keeping the writing on the Mac, and leave room for the engine to become more ambitious without turning the app into an account, a subscription or a surveillance device.

## Persian, mixed-language writing and پانویس

Persian interaction is built into the editor rather than placed in a separate mode:

- Arabic-script paragraphs are detected automatically and switch to right-to-left direction and right alignment.
- Persian runs receive a room-appropriate installed font, with preferences for Vazirmatn, Noto Arabic, SF Arabic, Geeza Pro, B Nazanin, Lalezar and related faces when available.
- English paragraphs in the same document remain left-to-right.
- Direction can always be overridden from **Format → Paragraph Direction**.
- A footnote inserted from a Persian paragraph becomes **پانویس**, uses Persian numerals such as **[۱]**, begins RTL and links back to its source marker.
- English footnotes remain **Footnotes [1]**; mixed-language documents can use a bilingual heading.

## Footnotes and academic writing

Press `Option–Command–F` or the **¹** control. The app inserts a superscript marker at the source, creates the corresponding note at the end of the document, and places the cursor where the note should be written. Clicking either number jumps between the text and the note.

RTF preserves superscript and links. Plain text preserves readable numbered markers and notes. This is intentionally the beginning of academic-writing support rather than a claim that Hello, Word is already a complete scholarly typesetting system.

## Sound and music

Every room ships with a three-minute ambient placeholder made to loop quietly. These are sound beds rather than songs: rain and room tone, restrained electrical hum, analog drift, translucent harmonics. They exist so that the music control does something on the first launch; they are emphatically placeholders, and part of the point is that each writer can eventually give these worlds a private soundtrack. There is an astonishing amount of excellent long-form ambient music online—rain rooms, library noise, tape loops, drones, spacecraft hum, old-computer soundscapes—and the app does not try to decide which of it belongs to you.

Please use recordings you made, purchased, downloaded with permission, or obtained under a license that allows personal use. A streaming webpage is not an audio file; Hello, Word needs the actual downloaded `.mp3`, `.m4a`, `.aac`, `.wav`, `.aif`, `.aiff` or `.caf` file.

### Adding your own music

1. Enter the world whose music you want to replace.
2. Click the small **folder** control beside the music button, or choose **Sound → Open This World’s Music Folder…**.
3. Finder opens the exact folder for that world.
4. Drag your downloaded ambient audio file into it.
5. Turn music off and on again—or leave and re-enter the world—to begin the new loop.

The first supported audio file alphabetically becomes that world's soundtrack and overrides the bundled placeholder. If you want to keep several alternatives in the folder, rename the one you want active so that it sorts first—for example, `01 My Library at Night.m4a`.

The music belongs to the world rather than to an individual document. A track placed in `library`, for example, will accompany every document you open in Midnight Library until you replace or remove it.

Personal music remains outside the signed app bundle, which means it can be changed freely without damaging the app or invalidating its signature. Do not put music inside `Hello, Word.app` itself.

The folders live under:

```text
~/Library/Application Support/Hello, Word/Music/
```

There is one subfolder for each world:

| World | Music folder |
|---|---|
| Still | `calm` |
| Macintosh 1999 | `mac1999` |
| System 95 | `system95` |
| DOS Midnight | `dos` |
| Typewriter | `typewriter` |
| Midnight Library | `library` |
| Space Age 1968 | `spaceAge` |
| Cyberdeck 2088 | `cyberdeck` |
| Hell | `hell` |
| Liquid Glass | `liquidGlass` |

If someone prefers to navigate there manually, Finder's **Go → Go to Folder…** command will accept the path above. The in-app folder button is easier and removes any possibility of choosing the wrong room.

## Documents and privacy

Hello, Word opens and saves `.txt`, `.md`, and `.rtf`. Previously saved documents are quietly autosaved after changes; a new unnamed piece of writing is never written anywhere until the writer chooses a location. Harper runs locally. Custom music stays local. There is no analytics system, login, cloud account or network service in the app.

Useful shortcuts:

| Shortcut | Action |
|---|---|
| `Command–S` | Save |
| `Command–O` | Open |
| `Command–F` | Find |
| `Option–Command–F` | Insert interactive footnote |
| `Command–\` | Reveal or hide controls |
| `Control–Command–F` | Enter or leave full screen |

## How the project is arranged

For anyone else who is not a coder—and, honestly, for me when I return to this six months from now—here is what each section does:

| Section | Responsibility |
|---|---|
| `Sources/HelloWord/AppDelegate.swift` | Builds the macOS menus and connects commands such as Open, Save, Footnote, World and Sound. |
| `Sources/HelloWord/MainWindowController.swift` | Creates the native application window and its full-screen behavior. |
| `Sources/HelloWord/MainViewController.swift` | Runs the editor: the fading controls, document operations, RTL detection, footnotes, writing width, splash card and correction timing. |
| `Sources/HelloWord/BackdropView.swift` | Draws the ten immersive environments, including their era-specific surfaces and details. |
| `Sources/HelloWord/WritingTheme.swift` | Defines each world's colors, fonts, spacing and overall visual identity. |
| `Sources/HelloWord/FocusTextView.swift` | Keeps the writing surface visually open while retaining native selection, links, spelling and text behavior. |
| `Sources/HelloWord/TypingAudioController.swift` | Generates the different keyboard, spacebar and Return sounds in real time. |
| `Sources/HelloWord/MusicLibrary.swift` | Finds bundled ambience and user-supplied music, then loops the right track for the current room. |
| `Sources/HelloWord/CorrectionEngine.swift` | Provides the Apple-backed and conservative local correction modes. |
| `Sources/HelloWord/HarperCorrectionService.swift` | Talks to the bundled Harper helper for private contextual English correction. |
| `Resources/World Art/` | Contains the original painterly Still, Typewriter, Midnight Library and Hell environments. |
| `Resources/` | Contains the icon, Info.plist, ambient placeholders, world art and Harper's required license/archive. |
| `Scripts/build-app.sh` | Compiles the Swift source, assembles the `.app`, adds resources and applies a local ad-hoc signature. |
| `Tools/generate_placeholder_music.py` | Recreates the ten original ambient placeholders when NumPy and FFmpeg are available. |
| `Documentation/ARCHITECTURE.md` | A more technical tour of how actions move through the app. |

## Building it yourself

You need a Mac, Xcode Command Line Tools and macOS 13 or later.

```bash
./Scripts/build-app.sh arm64
```

The finished application appears at:

```text
dist/arm64/Hello, Word.app
```

The build uses only Apple's installed frameworks and the verified Harper archive already included in `Resources/Harper`; it does not fetch private dependencies or require credentials.

## What remains unfinished

This is a real working app, but it is also the first public build. A few things remain deliberately candid:

- The downloadable preview currently supports Apple-silicon Macs and is not yet notarized by Apple.
- Document support is TXT/Markdown/RTF rather than DOCX, PDF or a proprietary library.
- Footnotes are practical linked notes, not yet a citation manager or page-layout engine.
- The correction system is substantially more contextual than native spelling, but it is not Microsoft Word and should not be advertised as infallible.
- The ambient tracks are original placeholders. They are meant to be replaced, extended and made stranger.

## Rights and acknowledgements

The Hello, Word source, icon, original world art and bundled ambient tracks are copyright © 2026 Morad Moazami. All rights are reserved for now; I have made the source visible so people can understand the project and help improve it, but I have not yet chosen a broader open-source license.

The bundled contextual checker is [Harper](https://github.com/Automattic/harper), distributed under the Apache License 2.0. Its license is preserved in `Resources/Harper/LICENSE.txt` and inside the application bundle.

The Typewriter world uses edited excerpts from recordings by Konrad Gutkowski / Work With Sounds and ramsamba. Their Creative Commons attribution and source links are preserved in `Resources/Typing Sounds/TYPEWRITER_LICENSE.txt` and inside the application bundle.

Hello, Word was inspired by the calm and discipline of OmmWriter, but its code, visual worlds, sounds and interface were built independently.
