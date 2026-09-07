#!/usr/bin/env bash
set -euo pipefail

# Recursos existentes
SUBSCRIPTION_ID="bb8def52-1f21-4498-b0ec-2c220264e518"
APP_RG="RG-Innovationlab-CR-01"
ACR_RG="RG-Innovationlab-CR-01"
ACR_NAME="crbloomberg"

ENVIRONMENT_NAME="cae-bloomberg-private"
ENVIRONMENT_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$APP_RG/providers/Microsoft.App/managedEnvironments/$ENVIRONMENT_NAME"
SUBNET_ID="/subscriptions/bb8def52-1f21-4498-b0ec-2c220264e518/resourceGroups/RG-Innovationlab-CR-01/providers/Microsoft.Network/virtualNetworks/vnet-innovationlab-cr-01/subnets/snet-containers"
LOG_WORKSPACE_NAME="log-vwksewpicguhq"
LOG_WORKSPACE_RG="rg-Innovationlab-CR-v2gptrag"
MODE="${1:-check}"
case "$MODE" in check|environment|deploy) ;; *) echo "Uso: bash $0 [check|environment|deploy]"; exit 2;; esac
APP_IDENTITY_ID="/subscriptions/bb8def52-1f21-4498-b0ec-2c220264e518/resourceGroups/RG-Innovationlab-CR-01/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-bloomberg-app"
MAIL_IDENTITY_ID="/subscriptions/bb8def52-1f21-4498-b0ec-2c220264e518/resourceGroups/RG-Innovationlab-CR-01/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-bloomberg-mail"

# Imágenes ya publicadas en ACR
# Valores observados en la aplicación original; se verifican en el ACR destino antes de desplegar.
BACKEND_TAG="${BACKEND_TAG:-email-html-20260902}"
FRONTEND_TAG="${FRONTEND_TAG:-mail-automation-20260825-1918}"

# Configuración Bloomberg
FOUNDRY_PROJECT_ENDPOINT="https://aif-bloomberg-cr.services.ai.azure.com/api/projects/aifp-bloomberg"
STORAGE_ACCOUNT_NAME="stbloomberg"
MAILBOX_ADDRESS="innovacion@caf-con.com"
APP_URL="${APP_URL:-}"

FRONTEND_NAME="ai-bloomberg-news-frontend"
BACKEND_NAME="ai-bloomberg-news-normal-chat"
JOB_NAME="ai-bloomberg-mail-job"

# Todas las consultas y operaciones usan la suscripción destino explícitamente.
az() { command az "$@" --subscription "$SUBSCRIPTION_ID"; }
command -v az >/dev/null
az group show -n "$APP_RG" --output none

ACR_SERVER=$(az acr show \
  --name "$ACR_NAME" --resource-group "$ACR_RG" \
  --query loginServer -o tsv)

APP_CLIENT_ID=$(az identity show \
  --ids "$APP_IDENTITY_ID" --query clientId -o tsv)

MAIL_CLIENT_ID=$(az identity show \
  --ids "$MAIL_IDENTITY_ID" --query clientId -o tsv)

BACKEND_IMAGE="$ACR_SERVER/bloomberg-news/normal-chat:$BACKEND_TAG"
FRONTEND_IMAGE="$ACR_SERVER/bloomberg-news/frontend:$FRONTEND_TAG"
STORAGE_URL="https://$STORAGE_ACCOUNT_NAME.blob.core.windows.net"

# El modo predeterminado solo consulta; no crea recursos ni envía correos.
az network vnet subnet show --ids "$SUBNET_ID" \
  --query '{rangos:addressPrefixes,delegaciones:delegations[].serviceName,nsg:networkSecurityGroup.id,rutas:routeTable.id}' -o json
if [[ "$MODE" == check ]]; then
  echo "Identidades y recursos consultados. Verificando imágenes en el ACR privado..."
  az acr repository show -n "$ACR_NAME" --image "bloomberg-news/normal-chat:$BACKEND_TAG" --output none
  az acr repository show -n "$ACR_NAME" --image "bloomberg-news/frontend:$FRONTEND_TAG" --output none
  echo "Imágenes disponibles. Falta validar RBAC, DNS, rutas y acceso al buzón desde CAF."
  exit 0
fi

# Detectar el entorno por inventario; no confundir errores de acceso con ausencia.
EXISTING_ENV_ID=$(az containerapp env list -g "$APP_RG" --query "[?name=='$ENVIRONMENT_NAME'].id | [0]" -o tsv)
if [[ -z "$EXISTING_ENV_ID" ]]; then
  LOG_ID=$(az monitor log-analytics workspace show -g "$LOG_WORKSPACE_RG" -n "$LOG_WORKSPACE_NAME" --query customerId -o tsv)
  LOG_KEY=$(az monitor log-analytics workspace get-shared-keys -g "$LOG_WORKSPACE_RG" -n "$LOG_WORKSPACE_NAME" --query primarySharedKey -o tsv)
  az containerapp env create -g "$APP_RG" -n "$ENVIRONMENT_NAME" \
    --location eastus --enable-workload-profiles true \
    --infrastructure-subnet-resource-id "$SUBNET_ID" --internal-only true \
    --logs-workspace-id "$LOG_ID" --logs-workspace-key "$LOG_KEY" --output none
  unset LOG_KEY
fi
ACTUAL_SUBNET=$(az containerapp env show -g "$APP_RG" -n "$ENVIRONMENT_NAME" --query properties.vnetConfiguration.infrastructureSubnetId -o tsv)
ACTUAL_INTERNAL=$(az containerapp env show -g "$APP_RG" -n "$ENVIRONMENT_NAME" --query properties.vnetConfiguration.internal -o tsv)
if [[ "$ACTUAL_SUBNET" != "$SUBNET_ID" || "$ACTUAL_INTERNAL" != true ]]; then
  echo "El entorno existente no coincide con la subred y el acceso interno previstos." >&2
  exit 1
fi
# Entregar a Infraestructura para la zona DNS del entorno y registro comodín.
az containerapp env show -g "$APP_RG" -n "$ENVIRONMENT_NAME" \
  --query '{dominio:properties.defaultDomain,ipPrivada:properties.staticIp}' -o json
if [[ "$MODE" == environment ]]; then exit 0; fi

# Validar imágenes antes de crear aplicaciones. No publicar ni abrir el ACR automáticamente.
az acr repository show -n "$ACR_NAME" --image "bloomberg-news/normal-chat:$BACKEND_TAG" --output none
az acr repository show -n "$ACR_NAME" --image "bloomberg-news/frontend:$FRONTEND_TAG" --output none
if [[ -z "$APP_URL" ]]; then
  read -r -p "URL HTTPS aprobada de Bloomberg (ejemplo propuesto: https://bloomberg.caf.com): " APP_URL
fi
if [[ "$APP_URL" != https://* || "$APP_URL" == *' '* ]]; then
  echo "Se requiere una URL HTTPS válida." >&2; exit 1
fi
APP_URL="${APP_URL%/}"
# No sobrescribir aplicaciones de intentos anteriores sin revisar su estado.
EXISTING_APPS=$(az containerapp list -g "$APP_RG" --query "[?name=='$BACKEND_NAME' || name=='$FRONTEND_NAME'].name" -o tsv)
EXISTING_JOB=$(az containerapp job list -g "$APP_RG" --query "[?name=='$JOB_NAME'].name" -o tsv)
if [[ -n "$EXISTING_APPS$EXISTING_JOB" ]]; then
  echo "Ya existe alguna aplicación o job Bloomberg. Revisar antes de actualizar; no se sobrescribe." >&2
  exit 1
fi

# Introducir el secreto sin guardarlo en este archivo.
read -r -s -p "Secreto de administración de Bloomberg: " ADMIN_SECRET
echo
if [[ -z "$ADMIN_SECRET" ]]; then
  echo "El secreto no puede estar vacío." >&2
  exit 1
fi

# 1. Backend: accesible solo dentro del entorno.
az containerapp create \
  --name "$BACKEND_NAME" \
  --resource-group "$APP_RG" \
  --environment "$ENVIRONMENT_ID" \
  --image "$BACKEND_IMAGE" \
  --user-assigned "$APP_IDENTITY_ID" "$MAIL_IDENTITY_ID" \
  --registry-server "$ACR_SERVER" \
  --registry-identity "$APP_IDENTITY_ID" \
  --ingress internal \
  --target-port 8001 \
  --transport auto \
  --cpu 1 \
  --memory 2Gi \
  --min-replicas 1 \
  --max-replicas 3 \
  --secrets "automation-admin-secret=$ADMIN_SECRET" \
  --env-vars \
    APP_ENV=production \
    AZURE_AUTH_MODE=managed-identity \
    "AZURE_CLIENT_ID=$APP_CLIENT_ID" \
    "AUTOMATION_MANAGED_IDENTITY_CLIENT_ID=$MAIL_CLIENT_ID" \
    AUTOMATION_ADMIN_SECRET=secretref:automation-admin-secret \
    "BLOOMBERG_MAILBOX_ADDRESS=$MAILBOX_ADDRESS" \
    "PUBLIC_APP_URL=$APP_URL" \
    SERVICE_PORT=8001 \
    "FOUNDRY_PROJECT_ENDPOINT=$FOUNDRY_PROJECT_ENDPOINT" \
    "AZURE_STORAGE_ACCOUNT_URL=$STORAGE_URL" \
    AZURE_STORAGE_UPLOAD_CONTAINER=uploads \
    FEEDBACK_BLOB_PREFIX=bloomberg-news/feedback \
    SAS_UPLOAD_TTL_MINUTES=15 \
    SAS_DOWNLOAD_TTL_MINUTES=10 \
    "CORS_ORIGINS=$APP_URL" \
    LOG_LEVEL=INFO \
    SDK_LOG_LEVEL=WARNING \
  --output none

unset ADMIN_SECRET

BACKEND_FQDN=$(az containerapp show \
  --name "$BACKEND_NAME" \
  --resource-group "$APP_RG" \
  --query properties.configuration.ingress.fqdn -o tsv)

# 2. Frontend: accesible desde la red mediante el entorno INTERNO.
# "external" significa fuera del entorno, no Internet en este caso.
az containerapp create \
  --name "$FRONTEND_NAME" \
  --resource-group "$APP_RG" \
  --environment "$ENVIRONMENT_ID" \
  --image "$FRONTEND_IMAGE" \
  --user-assigned "$APP_IDENTITY_ID" \
  --registry-server "$ACR_SERVER" \
  --registry-identity "$APP_IDENTITY_ID" \
  --ingress external \
  --target-port 80 \
  --transport auto \
  --cpu 0.5 \
  --memory 1Gi \
  --min-replicas 1 \
  --max-replicas 2 \
  --env-vars \
    "BACKEND_NORMAL_CHAT_UPSTREAM=https://$BACKEND_FQDN" \
    NORMAL_CHAT_UPSTREAM_MODE=direct \
  --output none

# 3. Trabajo de correo: misma imagen del backend, sin ingress.
# Se ejecuta cada 15 minutos, de lunes a viernes, en UTC.
az containerapp job create \
  --name "$JOB_NAME" \
  --resource-group "$APP_RG" \
  --environment "$ENVIRONMENT_ID" \
  --trigger-type Schedule \
  --cron-expression "*/15 * * * 1-5" \
  --image "$BACKEND_IMAGE" \
  --mi-user-assigned "$MAIL_IDENTITY_ID" \
  --registry-server "$ACR_SERVER" \
  --registry-identity "$MAIL_IDENTITY_ID" \
  --command python3 \
  --args automation_worker.py \
  --cpu 1 \
  --memory 2Gi \
  --parallelism 1 \
  --replica-completion-count 1 \
  --replica-timeout 1200 \
  --replica-retry-limit 1 \
  --env-vars \
    APP_ENV=production \
    AZURE_AUTH_MODE=managed-identity \
    "AZURE_CLIENT_ID=$MAIL_CLIENT_ID" \
    "BLOOMBERG_MAILBOX_ADDRESS=$MAILBOX_ADDRESS" \
    "PUBLIC_APP_URL=$APP_URL" \
    "FOUNDRY_PROJECT_ENDPOINT=$FOUNDRY_PROJECT_ENDPOINT" \
    "AZURE_STORAGE_ACCOUNT_URL=$STORAGE_URL" \
    AZURE_STORAGE_UPLOAD_CONTAINER=uploads \
    LOG_LEVEL=INFO \
    SDK_LOG_LEVEL=WARNING \
  --output none

# Mostrar el destino que utilizará Application Gateway.
az containerapp show \
  --name "$FRONTEND_NAME" \
  --resource-group "$APP_RG" \
  --query properties.configuration.ingress.fqdn \
  --output tsv
