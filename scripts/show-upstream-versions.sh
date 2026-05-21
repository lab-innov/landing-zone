#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

python3 - <<'PY'
import json
from pathlib import Path

path = Path("/Users/unidentified/Documents/Landing Zone/references/upstream-sources.json")
data = json.loads(path.read_text())
print("Repositorios fijados")
print("====================")
for src in data["sources"]:
    print(f"- {src['name']}: {src['ref']} @ {src['commit']}")
PY
