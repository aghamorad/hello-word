#!/usr/bin/env python3
"""Convert the unabridged Grady Ward Moby Thesaurus II into Apple DDK XML."""
from pathlib import Path
from html import escape
import json
import plistlib
import re
import sys
import xml.etree.ElementTree as ET

source=Path(sys.argv[1])
output=Path(sys.argv[2])
output.mkdir(parents=True, exist_ok=True)
payload=source.read_bytes()
try:
    text=payload.decode("utf-8-sig")
except UnicodeDecodeError:
    text=payload.decode("latin-1")
clean_bad=re.compile(r"[^\x09\x0A\x0D\x20-\uD7FF\uE000-\uFFFD\U00010000-\U0010FFFF]")
def clean(s):
    return clean_bad.sub("",s.strip())

headwords=0
associations=0
max_assoc=0
xml_path=output/"Moby.xml"
with xml_path.open("w",encoding="utf-8") as f:
    f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
    f.write('<d:dictionary xmlns="http://www.w3.org/1999/xhtml" xmlns:d="http://www.apple.com/DTDs/DictionaryService-1.0.rng">\n')
    for number,line in enumerate(text.splitlines(),1):
        if not line.strip(): continue
        fields=line.split(",")
        head=clean(fields[0])
        terms=[clean(t) for t in fields[1:]]
        terms=[t for t in terms if t]
        if not head or not terms: raise SystemExit(f"Malformed line {number}")
        headwords+=1
        associations+=len(terms)
        max_assoc=max(max_assoc,len(terms))
        h=escape(head,quote=True)
        f.write(f'<d:entry id="moby_{headwords:05d}" d:title="{h}"><d:index d:value="{h}"/><h1>{h}</h1><p class="count">{len(terms)} related terms</p>')
        for i in range(0,len(terms),45):
            f.write('<p class="terms">'+escape(", ".join(terms[i:i+45]))+'</p>')
        f.write('</d:entry>\n')
    f.write('</d:dictionary>\n')
if headwords!=30260:
    raise SystemExit(f"Unexpected {headwords} headwords, expected 30260")
ET.parse(xml_path)
plist={
    "CFBundleDevelopmentRegion":"English",
    "CFBundleIdentifier":"org.moby-thesaurus.apple-dictionary",
    "CFBundleName":"Moby Thesaurus II",
    "CFBundleShortVersionString":"1.0.0",
    "DCSDictionaryCopyright":"Moby Thesaurus II data, Grady Ward, public-domain grant, 2001.",
    "DCSDictionaryManufacturerName":"Grady Ward (data); macOS conversion project (packaging)",
    "DCSDictionaryUseSystemAppearance":True,
}
with (output/"Moby.plist").open("wb") as f:
    plistlib.dump(plist,f)
(output/"Moby.css").write_text('h1{font-size:1.32em;margin:0 0 .35em}p.count{font-size:.8em;color:#777}p.terms{line-height:1.55;margin:0 0 .7em;overflow-wrap:break-word}\n',encoding="utf-8")
(output/"source-statistics.json").write_text(json.dumps({"headwords":headwords,"associations":associations,"max_associations_per_headword":max_assoc,"source_bytes":len(payload)},indent=2)+"\n",encoding="utf-8")
print(f"Converted {headwords:,} headwords; {associations:,} associations",flush=True)
