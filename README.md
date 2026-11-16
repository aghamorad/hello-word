# Moby Thesaurus II for native macOS Dictionary

This is a dedicated **temporary build branch** for the independent Moby Thesaurus project. It does not modify the owner's Persian-English dictionary project.

The target is a native `Moby Thesaurus II.dictionary` bundle that works offline in Apple's Dictionary.app and its system-wide **Look Up** feature (rather than a browser app).

Moby II contains about 30,260 headwords and 2.5 million synonyms and related-term associations. It is useful for associative word discovery, but lists are not ranked by sense or usage; not every related term is a direct synonym.

The project uses Grady Ward's public-domain Moby data and a separately downloaded third-party mirror of Apple's Dictionary Development Kit. The binary DDK mirror has not been audited. Its macOS compatibility is not guaranteed until this workflow passes.

Once a successful workflow run has produced **Moby Thesaurus II.dictionary.zip**, unzip it, copy the entire `.dictionary` bundle to `~/Library/Dictionaries`, then enable **Moby Thesaurus II** under Dictionary → Settings. Search a headword in Dictionary, or select text in another app and choose **Look Up**.

Source: https://www.gutenberg.org/ebooks/3202
Compiler mirror: https://github.com/ikey4u/macddk
