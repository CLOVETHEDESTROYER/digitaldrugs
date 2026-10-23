#!/usr/bin/env python3
"""Stage plain file contents outside synced Documents; avoids clonefile stalls and signing metadata."""
from pathlib import Path
import hashlib, os, tempfile
studio = Path(__file__).resolve().parents[1]
key = hashlib.sha256(str(studio).encode()).hexdigest()[:12]
cache = Path.home() / 'Library/Caches/ZenWaveContentStudio' / key
stage = cache / 'Source'
files = [studio / 'Package.swift']
for directory in ('Sources', 'Tests'):
    files += [p for p in (studio / directory).rglob('*') if p.is_file() and p.name != '.DS_Store']
expected = set()
for source in files:
    relative = source.relative_to(studio)
    expected.add(relative)
    target = stage / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    data = source.read_bytes()
    if target.exists() and target.read_bytes() == data:
        continue
    fd, name = tempfile.mkstemp(dir=target.parent)
    with os.fdopen(fd, 'wb') as stream:
        stream.write(data)
    os.replace(name, target)
for directory in ('Sources', 'Tests'):
    if (stage / directory).exists():
        for target in (stage / directory).rglob('*'):
            if target.is_file() and target.relative_to(stage) not in expected:
                target.unlink()
print(stage)
