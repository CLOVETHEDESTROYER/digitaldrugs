#!/usr/bin/env python3
"""Snapshot the app's source catalog without modifying the iOS target."""
from pathlib import Path
import subprocess, tempfile, shutil
studio = Path(__file__).resolve().parents[1]
repo = studio.parent
resources = studio / 'Sources/ZenWaveStudio/Resources'
source = (repo / 'Models/ManifestationModels.swift').read_text().split('extension GuidedRitual {')[0]
exporter = r'''
import Foundation
func record(_ mantra: ManifestationMantra, timing: String, category: String) -> [String: Any] {
    ["id": mantra.id, "title": mantra.title, "subtitle": mantra.subtitle,
     "fileName": mantra.fileName, "timing": timing, "category": category,
     "cues": mantra.cues.map { cue in
        ["start": cue.startTime, "end": cue.endTime, "text": cue.text] as [String: Any]
     }]
}
var records = ManifestationMantra.library.map { record($0, timing: "timed", category: "Original mantras") }
for practice in ManifestationMantraPractice.library {
    if let morning = practice.morning { records.append(record(morning, timing: "estimated", category: "Morning")) }
    records.append(record(practice.evening, timing: "estimated", category: "Evening"))
}
let data = try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
'''
with tempfile.TemporaryDirectory() as tmp:
    script = Path(tmp) / 'main.swift'
    script.write_text(source + exporter)
    subprocess.run(['xcrun', 'swift', str(script), str(resources / 'catalog.json')], check=True)
audio = resources / 'Audio'
audio.mkdir(exist_ok=True)
import json
records = json.loads((resources / 'catalog.json').read_text())
for record in records:
    original = repo / 'Audio/ManifestationMantras' / record['fileName']
    if not original.exists(): raise FileNotFoundError(original)
    shutil.copy2(original, audio / original.name)
print(f'Synced {len(records)} mantras. Studio-specific visualizers were preserved.')

# Bundle the existing local nature recordings for offline studio use.
nature = resources / 'Nature'
nature.mkdir(exist_ok=True)
for original in [*(repo / 'Audio/NatureSounds').glob('*.m4a'), repo / 'Audio/Ocean.wav']:
    (nature / original.name).write_bytes(original.read_bytes())
print('Synced bundled nature sounds.')

brand = resources / 'Brand'
brand.mkdir(exist_ok=True)
logo = repo / 'DigitalDrug/Assets.xcassets/ZenWaveBrandMark.imageset/ZenWaveBrandMark.png'
(brand / 'ZenWaveLogo.png').write_bytes(logo.read_bytes())
print('Synced the official ZenWave brand mark.')

# Preserve the exact chakra recordings, pitch-preserving column loops, and artwork.
chakra = resources / 'Chakra'
chakra.mkdir(exist_ok=True)
for original in (repo / 'Audio/ChakraSounds').glob('*.m4a'):
    (chakra / original.name).write_bytes(original.read_bytes())
(chakra / 'ColumnLoops').mkdir(exist_ok=True)
for original in (repo / 'Audio/ChakraSounds/ColumnLoops').glob('*'):
    if original.is_file(): (chakra / 'ColumnLoops' / original.name).write_bytes(original.read_bytes())
(chakra / 'chakra-column.png').write_bytes((repo / 'DigitalDrug/Assets.xcassets/ChakraColumn.imageset/chakra-column.png').read_bytes())
print('Synced chakra recordings, column loops and official column artwork.')
