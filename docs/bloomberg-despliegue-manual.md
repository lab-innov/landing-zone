# Bloomberg privado: ejecución manual

Script: `scripts/deploy-bloomberg-private.sh`. Preparado con consultas de Azure del
7 de septiembre de 2026. No se ha ejecutado el despliegue.

## Recursos verificados

- Suscripción destino: `bb8def52-1f21-4498-b0ec-2c220264e518`.
- RG de aplicaciones: `RG-Innovationlab-CR-01` (seleccionado por el usuario).
- RG de dependencias: `RG-Innovationlab-CR-01`.
- VNet: `vnet-innovationlab-cr-01`; `snet-containers`: `10.92.40.0/23`, delegada a `Microsoft.App/environments`.
- Entorno propuesto nuevo: `cae-bloomberg-private`, interno, en `eastus`, con workload profiles.
- Log Analytics existente: `log-vwksewpicguhq`, en `rg-Innovationlab-CR-v2gptrag`.
  `LOG_WORKSPACE_RG` es independiente de `APP_RG`.
- Identidades existentes: `id-bloomberg-app` e `id-bloomberg-mail`.
- ACR: `crbloomberg.azurecr.io`, Premium, acceso público deshabilitado.
- Storage de aplicación: `stbloomberg`.
- Proyecto: `https://aif-bloomberg-cr.services.ai.azure.com/api/projects/aifp-bloomberg`.
- Buzón de la aplicación original: `innovacion@caf-con.com`.

El entorno existente `cae-vwksewpicguhq` pertenece a otra VNet y no se modifica.
Las identidades nuevas requieren sus propios permisos; no heredan los de la aplicación original.

## Ejecutar

Desde la raíz del repositorio:

```bash
# Solo consultas; falla si no puede comprobar imágenes privadas.
bash scripts/deploy-bloomberg-private.sh check

# Crear o reutilizar únicamente el entorno interno.
bash scripts/deploy-bloomberg-private.sh environment

# Crear el entorno si falta, dos apps y el job programado.
APP_URL=https://DOMINIO_APROBADO bash scripts/deploy-bloomberg-private.sh deploy
```

El modo `deploy` solicita el secreto de administración sin mostrarlo. No ejecutar
con trazas de shell (`set -x`). El job queda programado inmediatamente; puede
leer y enviar correo conforme a la configuración guardada. El script no ejecuta
un envío de prueba ni copia datos desde el Storage original.

## Pendientes antes de activar Bloomberg

- Infraestructura debe completar NSG, rutas y DNS: la subred consultada no tenía NSG ni tabla de rutas.
- Asociar los endpoints a DNS central. Para ACA, el modo `environment` devuelve
  el dominio y la IP privada para configurar la zona y el registro comodín.
- Autorizar las identidades en ACR, Blob, Foundry y el buzón. El script no crea
  asignaciones explícitas, pero Azure CLI puede intentar asignar acceso ACR;
  un error `roleAssignments/write` todavía requiere intervención de Infraestructura.
- Verificar el contenedor `uploads`, los modelos y el agente esperado en el nuevo
  proyecto Foundry. Crear infraestructura no copia agentes ni publica versiones.
- Autorizar las salidas requeridas a Microsoft Graph y autenticación.
- Definir DNS y certificado de Application Gateway. `bloomberg.caf.com` es solo
  una propuesta, no una asignación confirmada. No existía Application Gateway en
  la suscripción consultada.
- Verificar las imágenes en el ACR destino desde CAF. El listado devolvió 403
  desde este equipo; no se confirmó si las imágenes ya están publicadas allí.
  Los valores predeterminados son las etiquetas observadas en la aplicación original:
  backend `email-html-20260902`, frontend `mail-automation-20260825-1918`.
  Se pueden cambiar mediante `BACKEND_TAG` y `FRONTEND_TAG`.

No crea zonas DNS, identidades, permisos, imágenes, gateway ni recursos de Foundry.
El entorno se reutiliza únicamente si coincide con la subred y el modo interno.
Si alguna app/job ya existe, se detiene para evitar sobrescribir intentos anteriores.
Validación local: sintaxis Bash; no demuestra aceptación de Azure ni conectividad.
