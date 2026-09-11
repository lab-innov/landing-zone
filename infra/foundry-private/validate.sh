#!/usr/bin/env bash
# Compila en una carpeta temporal y comprueba contratos sin consultar Azure.
set -euo pipefail
foundry_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
foundry_temp="$(mktemp -d)"
trap 'rm -rf "$foundry_temp"' EXIT
if command -v bicep >/dev/null 2>&1; then
  bicep build "$foundry_root/main.bicep" --outfile "$foundry_temp/main.json"
  bicep lint "$foundry_root/main.bicep"
else
  az bicep build --file "$foundry_root/main.bicep" --outfile "$foundry_temp/main.json"
  az bicep lint --file "$foundry_root/main.bicep"
fi
ARM_TEMPLATE="$foundry_temp/main.json" PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "$foundry_root/tests" -v
