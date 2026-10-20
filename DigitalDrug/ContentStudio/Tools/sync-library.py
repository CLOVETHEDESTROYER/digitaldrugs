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
shutil.copy2(repo / 'DigitalDrug/Visualizations/ZenWaveVisualizer.metal', resources / 'Visualizer.metal')
audio = resources / 'Audio'
audio.mkdir(exist_ok=True)
import json
records = json.loads((resources / 'catalog.json').read_text())
for record in records:
    original = repo / 'Audio/ManifestationMantras' / record['fileName']
    if not original.exists(): raise FileNotFoundError(original)
    shutil.copy2(original, audio / original.name)
print(f'Synced {len(records)} mantras and the original Metal shader.')
