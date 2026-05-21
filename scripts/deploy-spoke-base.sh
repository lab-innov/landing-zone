#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_DIR="${REPO_ROOT}/infra/spoke-base"

ENV_FILE="${1:-}"
ACTION="${2:-create}"
DEPLOYMENT_NAME="${3:-spoke-base-$(date +%Y%m%d%H%M%S)}"

if [[ -z "${ENV_FILE}" ]]; then
  echo "Uso: $0 <archivo.env> [create|what-if|validate] [deployment-name]" >&2
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "No existe el archivo de entorno: ${ENV_FILE}" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

if [[ -z "${AZURE_LOCATION:-}" ]]; then
  echo "La variable AZURE_LOCATION es obligatoria." >&2
  exit 1
fi

case "${ACTION}" in
  create)
    az deployment sub create \
      --name "${DEPLOYMENT_NAME}" \
      --location "${AZURE_LOCATION}" \
      --template-file "${TARGET_DIR}/main.bicep" \
      --parameters "${TARGET_DIR}/main.bicepparam"
    ;;
  what-if)
    az deployment sub what-if \
      --name "${DEPLOYMENT_NAME}" \
      --location "${AZURE_LOCATION}" \
      --template-file "${TARGET_DIR}/main.bicep" \
      --parameters "${TARGET_DIR}/main.bicepparam"
    ;;
  validate)
    az deployment sub validate \
      --name "${DEPLOYMENT_NAME}" \
      --location "${AZURE_LOCATION}" \
      --template-file "${TARGET_DIR}/main.bicep" \
      --parameters "${TARGET_DIR}/main.bicepparam"
    ;;
  *)
    echo "Acción no soportada: ${ACTION}" >&2
    exit 1
    ;;
esac
