#!/bin/bash
set -euo pipefail
mkdir -p build/source dist
curl -fL --retry 3 --silent --show-error https://www.gutenberg.org/files/3202/files/mthesaur.txt -o build/mthesaur.txt
python3 scripts/convert.py build/mthesaur.txt build/source
xmllint --noout build/source/Moby.xml
plutil -lint build/source/Moby.plist
git clone --depth 1 https://github.com/ikey4u/macddk.git build/ddk
export DICT_DEV_KIT_OBJ_DIR="$(pwd)/build/objects"
sh build/ddk/bin/build_dict.sh -v 10.11 "Moby Thesaurus II" build/source/Moby.xml build/source/Moby.css build/source/Moby.plist
BUNDLE="build/objects/Moby Thesaurus II.dictionary"
test -d "$BUNDLE"
for f in Body.data KeyText.index EntryID.index; do
    find "$BUNDLE" -name "$f" -type f -print -quit | grep -q .
done
ditto "$BUNDLE" "dist/Moby Thesaurus II.dictionary"
(cd dist && ditto -c -k --keepParent "Moby Thesaurus II.dictionary" "Moby Thesaurus II.dictionary.zip" && shasum -a 256 "Moby Thesaurus II.dictionary.zip" > SHA256SUMS.txt)
echo "SUCCESS: compiled native Apple Dictionary bundle."
