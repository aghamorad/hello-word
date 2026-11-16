# Native Moby Thesaurus II macOS build

A fully offline, searchable Apple Dictionary source based on Grady Ward's Moby Thesaurus II. This package is designed to extend the synonyms visible while writing in macOS apps.

- 30,260 headwords from the original Moby data.
- Approximately 2.5 million associations, not all exact synonyms.
- No subscription, account, Internet lookup, or standalone app after installation.
- Native `.dictionary` compiled using Apple's Dictionary Development Kit.
- The original Moby data has a public-domain grant; Apple's separate compiler is not redistributed.

**Installation:** Download the generated `Moby Thesaurus II.dictionary.zip`. Unzip it and move the `.dictionary` bundle into `~/Library/Dictionaries`. In **Dictionary → Settings**, enable the Moby source. Test via Dictionary and **Look Up** in a supported app.

**Status:** A successful compilation CI run verifies that a binary bundle exists; it does not prove compatibility with every macOS release or in-app runtime behaviour. Avoid claiming that Look Up has been tested on a physical Mac until it has.
