# Guía de despliegue del gateway de IA

## Qué se entrega

El gateway ofrece a las aplicaciones de CAF una entrada común a los modelos de Azure OpenAI. Identifica qué aplicación llama, comprueba su autorización y aplica límites de consumo por iniciativa. Los modelos y sus datos permanecen en las cuentas donde ya están alojados.

**API Management (APIM) es el servicio de Azure. AI Gateway es la función que desempeña al administrar las llamadas de IA.** No se necesitan dos servicios diferentes por esos nombres.

La entrega está en la rama `ai-gateway`, con un worktree independiente en `../landing-zone-ai-gateway`. El código propio se encuentra en `infra/ai-gateway`. No sustituye automáticamente a `infra/hub-governance` ni debe desplegarse junto con aquel sobre una misma instancia.

## Decisión propuesta

Reutilizar el APIM corporativo si Operaciones confirma que dispone de conectividad privada hacia los modelos, capacidad suficiente, identidad administrada y un responsable que pueda administrar estas APIs. Si necesitan capacidad, costos y administración independientes, usar la instancia dedicada opcional.

| Alternativa | Qué se despliega | Condición |
| --- | --- | --- |
| APIM corporativo | Rutas y políticas de IA; permisos sobre las cuentas de modelos | Revisar antes los nombres existentes, las políticas heredadas y la capacidad compartida |
| APIM dedicado | Standard v2, endpoint privado, diagnósticos, rutas y permisos | Confirmar región, presupuesto, red y aceptación del aprovisionamiento inicial |

Standard v2 es la base propuesta para la alternativa dedicada porque permite combinar entrada mediante endpoint privado con salida hacia modelos privados. Una unidad es un punto de partida pendiente de prueba de carga, no un dimensionamiento definitivo ni una promesa de disponibilidad. Confirmar disponibilidad regional, límites y precio vigente antes de aprobar su contratación.

Esta versión configura APIs en el nivel del servicio APIM. No crea el workspace `ws-ai` ni el gateway de workspace `gw-ai`: esa alternativa mencionada en las referencias de CAF requiere una decisión específica de plataforma. Tampoco crea Products, pues la autorización inicial se realiza con identidades de aplicaciones y roles, sin claves de suscripción de APIM.

## Funcionamiento inicial

```text
Aplicación CAF con identidad autorizada
    → red privada CAF → APIM /ai/<iniciativa>/chat/completions
    → identidad administrada de APIM → modelo privado de Azure OpenAI
```

Cada iniciativa tiene una ruta, aplicaciones autorizadas, un despliegue de modelo y límites propios. Una iniciativa no puede elegir otro modelo mediante la URL. El gateway fija el despliegue y la versión de API; no transmite parámetros de consulta libres al modelo.

La versión inicial admite `POST /chat/completions`, incluyendo respuestas en streaming. No expone rutas comodín, Responses, archivos, asistentes, embeddings ni operaciones administrativas. Las aplicaciones deberán ajustar su URL; no es una sustitución transparente de todos los métodos del SDK de Azure OpenAI.

Los límites de ejemplo —60 solicitudes por minuto, 10.000 tokens por minuto y 1.000.000 de tokens al mes— deben ajustarse por iniciativa. Son límites compartidos por las aplicaciones de esa iniciativa. El conteo de tokens puede tener exceso temporal por concurrencia y estimaciones en streaming; no equivale a un presupuesto financiero ni a la factura de Azure. Los límites no se agregan entre gateways regionales independientes.

No se añaden caché de conversaciones, reintentos automáticos, cambio automático de modelo ni registro deliberado de prompts/respuestas. En un APIM compartido deben revisarse las políticas y diagnósticos heredados, pues pueden cambiar este comportamiento. La sección de backend usa un envío explícito para permitir streaming y no hereda la sección backend corporativa; Operaciones debe aprobar esa compatibilidad antes de incorporar la API. Las secciones de entrada, salida y error sí heredan las políticas superiores.

## Recursos y responsabilidades

| Elemento | Responsable y resultado |
| --- | --- |
| APIM nuevo, si corresponde | `foundation.bicep`: instancia Standard v2 con identidad de sistema, endpoint privado y diagnósticos hacia Log Analytics existente |
| APIs por iniciativa | `main.bicep`: ruta de chat, destino fijo, autorización Entra y límites |
| Permiso de inferencia | `backend-access.bicep`: Cognitive Services OpenAI User para la identidad de APIM, limitado a cada cuenta autorizada |
| Grupo de recursos | Operaciones entrega un grupo existente; las plantillas no lo crean |
| VNet y subredes | Operaciones entrega la red aprobada; estas plantillas no crean ni modifican VNet, NSG o rutas |
| DNS y conectividad CAF | Operaciones administra DNS central, zone groups/DINE, rutas y conexión con las redes de los modelos |
| Modelos y cuentas OpenAI | Cada iniciativa entrega cuenta, despliegue, versión compatible y capacidad disponible |
| Aplicaciones Entra | Identidad crea el registro que representa al gateway y concede su rol a los consumidores autorizados |
| Observabilidad | Operaciones entrega Log Analytics central y revisa acceso, retención y conectividad de Azure Monitor |

El permiso de APIM alcanza la cuenta OpenAI, no solamente un despliegue. La restricción por modelo se aplica en las rutas del gateway. Para aislamiento de permisos más fuerte se necesitan cuentas o identidades separadas. Si los consumidores conservan acceso directo a los modelos, pueden eludir las cuotas del gateway; su retiro requiere una migración coordinada y no está incluido aquí.

## Información que debe entregar Operaciones

1. Tenant, suscripción, grupo de recursos y región de destino; propietario, clasificación de datos y etiquetas.
2. Nombre del APIM corporativo, o aprobación de la instancia dedicada y su costo.
3. Para la instancia nueva, dos subredes existentes: una exclusiva de integración y otra para el endpoint privado. La de integración debe estar en la misma suscripción y región de APIM, delegada a `Microsoft.Web/serverFarms`, con NSG, mínimo `/27` y tamaño recomendado `/24` si se requiere crecimiento. No asignar rangos sin IPAM.
4. Resolución corporativa de `privatelink.azure-api.net` y de los endpoints privados de Azure OpenAI; rutas desde los consumidores hacia APIM y desde APIM hacia las cuentas. La integración de salida por sí sola no cierra el ingreso público.
5. Salidas requeridas por el servicio y Entra, incluidas las dependencias de Key Vault por HTTPS; compatibilidad de firewall, rutas y DNS con Standard v2. El endpoint privado cubre el gateway, no todos los portales o planos administrativos.
6. ID de Log Analytics central. El módulo opcional crea `ai-gateway-central` con `GatewayLogs` y `AllMetrics`; en un APIM existente confirmar un diagnóstico equivalente antes de habilitar consumidores y evitar duplicar destinos.
7. Por iniciativa: nombre corto, client IDs autorizados, cuenta OpenAI, grupo y suscripción de esa cuenta, despliegue, versión de API y límites aprobados.
8. Registro de Entra del gateway: audiencia exacta del token y rol de aplicación `AiGateway.Invoke`, permitido para aplicaciones. Concederlo a cada identidad consumidora y configurar emisión de tokens de aplicación; esta base no implementa acceso delegado de usuarios.

No se requiere crear nuevos modelos Foundry, Storage, Key Vault, Event Hubs, Functions o Logic Apps para esta base. Esos componentes del acelerador completo se evalúan cuando exista una necesidad concreta de reportes o funcionalidades adicionales.

## Preparación

Usar Azure CLI, Bicep actualizado y Python 3. Iniciar sesión con la identidad autorizada. Confirmar tenant y suscripción con `az account show`; no asumir que la sesión local apunta al destino correcto.

El operador requiere permisos para desplegar recursos en el grupo de APIM, unir la subred y crear el endpoint privado. Quien ejecute `backend-access.bicep` debe poder crear asignaciones de roles en la cuenta OpenAI; Contributor por sí solo no concede esa facultad. Operaciones comprueba proveedores registrados, políticas heredadas y permisos entre suscripciones.

Desde la raíz del worktree:

```bash
cp environments/ai-gateway/configuration.example.bicepparam environments/ai-gateway/configuration.local.bicepparam
cp environments/ai-gateway/foundation.example.bicepparam environments/ai-gateway/foundation.local.bicepparam
cp environments/ai-gateway/backend-access.example.bicepparam environments/ai-gateway/backend-access.local.bicepparam
```

Completar los archivos locales con los valores aprobados. Están excluidos de Git. Los ejemplos contienen marcadores y no están listos para desplegar. Si se usa APIM corporativo, omitir completamente la plantilla de creación de instancia.

## Secuencia de despliegue

Cada fila corresponde a una ejecución separada. Revisar el resultado antes de pasar a la siguiente.

| Orden | Archivo local | Grupo y suscripción de destino | Resultado esperado |
| --- | --- | --- | --- |
| 1, solo instancia nueva | `foundation.local.bicepparam`, con `stage = 'inicial'` | Grupo de APIM | APIM y endpoint privado creados; todavía sin APIs de IA |
| 2, solo instancia nueva | El mismo archivo, ahora con `stage = 'privada'` | Grupo de APIM | Ingreso público deshabilitado |
| 3, por cuenta OpenAI | `backend-access.local.bicepparam` | Grupo de cada cuenta OpenAI | Identidad de APIM autorizada a inferir |
| 4 | `configuration.local.bicepparam` | Grupo de APIM | Rutas protegidas disponibles para las pruebas privadas |

**La etapa inicial de la instancia nueva mantiene acceso público mientras Azure crea el endpoint.** Se limita al aprovisionamiento, sin incorporar consumidores ni APIs de IA. Requiere aceptación de Operaciones y compatibilidad con Azure Policy. Si la organización prohíbe ese estado transitorio, no ejecutar esa etapa: reutilizar una instancia privada existente o acordar otra modalidad de red. No deshabilitar políticas para forzar el despliegue.

Entre las etapas 1 y 2, comprobar que el endpoint esté `Approved`, que DINE haya completado la configuración DNS y que el nombre de APIM resuelva a la IP privada desde CAF. Si falla la creación del endpoint, la instancia puede permanecer pública: no agregar APIs, resolver la causa y completar el cierre antes de continuar. No volver a ejecutar la etapa `inicial` sobre una instancia existente.

Antes de la etapa 3, obtener el `principalId` de los outputs de la instancia nueva o de la identidad de sistema del APIM corporativo; usarlo como `apimPrincipalId`. Aplicar el permiso una vez por cuenta y esperar la propagación. No es el client ID de la aplicación consumidora.

### Revisar y ejecutar cada etapa

Asignar las variables a los valores reales de la fila correspondiente. El nombre de despliegue debe distinguir instancia, permisos y configuración.

```bash
SUBSCRIPTION_ID='PENDIENTE'
RESOURCE_GROUP='PENDIENTE'
DEPLOYMENT_NAME='PENDIENTE'
PARAMETERS='environments/ai-gateway/configuration.local.bicepparam'
COMPILED='environments/ai-gateway/revision.local.json'

az bicep build-params --file "$PARAMETERS" --outfile "$COMPILED"
python3 scripts/check-ai-gateway.py "$COMPILED"
python3 scripts/preflight-ai-gateway.py "$COMPILED" \
  --subscription "$SUBSCRIPTION_ID" --resource-group "$RESOURCE_GROUP"

az deployment group validate --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" \
  --parameters "$PARAMETERS"

az deployment group what-if --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" \
  --parameters "$PARAMETERS"
```

Detenerse ante cualquier error. El preflight solo consulta Azure: rechaza parámetros pendientes, reapertura de una instancia existente mediante la etapa inicial y configuración de APIs sin ingreso privado e identidad de sistema. No certifica DNS, rutas, permisos de inferencia ni políticas efectivas. Ejecutar directamente Bicep evita estas comprobaciones auxiliares; utilizar la secuencia completa.

Revisar que el `what-if` afecte exclusivamente a los recursos esperados. En APIM compartido, revisar colisiones con los nombres `ai-<iniciativa>` y las rutas `ai/<iniciativa>`; no sobrescribir una API preexistente sin acordar su titularidad. Usar despliegue incremental, nunca completo.

Con el despliegue autorizado y el resultado revisado:

```bash
az deployment group create --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" \
  --mode Incremental --parameters "$PARAMETERS"
```

Al cerrar la instancia nueva, guardar `stage = 'privada'` en el archivo local para las actualizaciones posteriores. La omisión de una iniciativa del archivo no elimina recursos ya desplegados: cualquier baja debe planificarse expresamente.

## Aceptación antes de incorporar aplicaciones

Realizar pruebas desde un cliente conectado a CAF y con una identidad de aplicación autorizada. Obtener el token para la audiencia del gateway usando el mecanismo aprobado de la aplicación; no usar un token dirigido a Cognitive Services ni guardar tokens en archivos del repositorio.

| Prueba | Resultado requerido |
| --- | --- |
| DNS y HTTPS desde CAF | Nombre del gateway resuelto a IP privada, certificado válido y conexión por 443 |
| Llamada privada sin token | Rechazo 401, sin llamada al modelo |
| Token de otra aplicación, tenant, audiencia o sin rol | Rechazo 401 |
| Aplicación autorizada con rol | Respuesta válida del modelo asignado |
| Ruta de otra iniciativa o despliegue no publicado | Rechazo por autorización o ruta inexistente |
| Exceso de solicitudes o tokens por minuto | Rechazo 429; ajustar límites de un piloto para comprobarlo |
| Cuota mensual agotada | Rechazo 403; probar con cuota pequeña de piloto |
| Respuesta en streaming | Fragmentos entregados progresivamente y consumo limitado conforme a la política |
| Llamada desde Internet | Sin acceso a la API; en Standard v2 con acceso público cerrado se espera rechazo de red del servicio |
| Observabilidad | Solicitud y error visibles por API/iniciativa en el destino central; revisar que no aparezcan Authorization, api-key, prompts o respuestas |

Ejemplo de cuerpo de una prueba de chat: `{"messages":[{"role":"user","content":"Responde solamente OK"}]}`. Enviarlo con `Content-Type: application/json` y `Authorization: Bearer <token>` a la URL entregada en los outputs. La ruta ya identifica el modelo, por lo que no se permite seleccionarlo por parámetro de consulta.

La observabilidad inicial permite seguimiento operativo por API, no un informe de costos imputados ni un registro financiero de tokens. El informe de uso avanzado del acelerador queda para una etapa posterior. El gateway tampoco sustituye los filtros de seguridad del modelo; confirmar su configuración en cada cuenta.

## Recuperación y cambios posteriores

Antes de actualizar una API utilizada, guardar su definición y políticas vigentes con el procedimiento corporativo, registrar el commit y conservar los parámetros locales de esa versión. Para recuperar una configuración, volver a aplicar la versión anterior revisada y repetir las pruebas privadas. Reaplicar la misma versión no debe cambiar nombres, rutas ni asignaciones de permisos.

Si la prueba piloto falla, no cambiar consumidores. Si la instancia ya está privada, mantener el cierre público. No eliminar APIM, endpoints, identidades ni permisos compartidos como mecanismo automático de recuperación. La retirada definitiva de APIs o roles debe limitarse a los recursos propios y contar con revisión operativa.

Para agregar otra iniciativa, añadir una entrada con su modelo, identidades y límites; conceder el acceso de APIM a su cuenta cuando corresponda, revisar `what-if` y repetir las pruebas de autorización entre iniciativas. Antes de habilitar nuevas familias de APIs, definir sus operaciones, política de consumo y pruebas específicas.

## Verificación de esta entrega

La entrega se comprobó localmente con compilación y linter de Bicep, compilación de los tres ejemplos, pruebas de contratos y revisión de diferencias. Estas comprobaciones no ejecutan el motor de políticas de APIM.

No se ejecutaron `validate`, `what-if`, despliegues ni pruebas funcionales en Azure. Región, presupuesto, IDs reales, conectividad y aceptación de la plataforma siguen pendientes. No se hizo push a Git.

## Fuentes y alcance de la adaptación

Se consultó el [acelerador AI Hub Gateway de Microsoft](https://github.com/Azure-Samples/ai-hub-gateway-solution-accelerator/tree/f2702b49f80d0ad40e227ae2ee9d8b6dd9137da4), fijado al commit ya registrado en este repositorio. Se revisaron su README, módulo APIM y fragmentos de autenticación. El nuevo código es una implementación propia de alcance reducido; no se copian sus archivos ni se instala Citadel completo.

Se adoptan el uso de APIM como entrada común, identidades administradas y políticas de gobierno. Se simplifica a Azure OpenAI y chat por iniciativa; autenticación obligatoria, modelos explícitos y DNS corporativo. No se incorporan almacenamiento de conversaciones, Redis, procesamiento de consumo, múltiples proveedores ni servicios adicionales del acelerador.

Referencias oficiales consultadas el 6 de octubre de 2026:

- [Endpoint privado y cierre del acceso público](https://learn.microsoft.com/azure/api-management/private-endpoint).
- [Integración de salida y requisitos de subred](https://learn.microsoft.com/azure/api-management/integrate-vnet-outbound).
- [Validación de tokens de Entra](https://learn.microsoft.com/azure/api-management/validate-azure-ad-token-policy).
- [Límites de tokens y sus restricciones](https://learn.microsoft.com/azure/api-management/llm-token-limit-policy).
- [Identidades administradas de APIM](https://learn.microsoft.com/azure/api-management/api-management-howto-use-managed-service-identity).
