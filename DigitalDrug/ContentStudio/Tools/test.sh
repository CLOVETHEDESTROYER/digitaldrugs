#!/bin/bash
set -euo pipefail
studio_dir="$(cd "$(dirname "$0")/.." && pwd)"
stage_dir="$(python3 "$studio_dir/Tools/stage-build.py")"
swift test --package-path "$stage_dir" --build-system native
