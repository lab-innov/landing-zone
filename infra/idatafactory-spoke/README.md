# Spoke privado de iDataFactory para CAF

Adaptación de `main-4.bicep` a un **entorno paralelo**, con nombres nuevos y recursos propios. La infraestructura compila; no equivale a una migración funcional completa. No modifica el archivo de Downloads ni el entorno actual. No se ha desplegado en Azure.

El exportado contiene 6 aplicaciones, 4 planes y una referencia a un quinto plan externo, 10 cuentas Storage, 3 Cosmos DB, OpenAI, Document Intelligence, Search, ACR, Databricks, Automation y Communication Services. No contiene ninguna VNet ni private endpoint. Data Factory está ausente según el error de exportación. `inventario-exportado.json` conserva tipos, símbolos y líneas de todos los recursos para revisar su cobertura sin incorporar configuraciones históricas al despliegue.

## Cambios aplicados

- VNet propia, DNS corporativo obligatorio, peering de salida al hub y ruta por defecto al firewall CAF para las subredes de cómputo.
- Cinco subredes de integración delegadas a `Microsoft.Web/serverFarms`, una por plan. Notifications y UserPermissions comparten plan y subred, como en el origen. El plan externo de procesamiento se reemplaza por uno dedicado nuevo; el plan web B1 pasa a P1v3. Los cinco planes nuevos generan costes incluso con aplicaciones detenidas.
- Entrada privada a las seis aplicaciones; HTTPS/TLS 1.2, publicación básica deshabilitada, salida de aplicación, contenido e imágenes por la VNet. Las aplicaciones se crean **detenidas**. Volver a aplicar el Bicep también las detiene: no usarlo como pipeline de mantenimiento después de la activación sin revisar este parámetro fijo.
- ACR Premium para Private Link, sin administrador ni bypass. Commons usa identidad administrada con `AcrPull`. Su imagen debe copiarse al ACR nuevo y validarse por digest antes de arrancar. No se modificó ni publicó código de contenedores; el exportado contiene App Service con contenedor, no Azure Container Apps.
- StorageV2 privado: endpoints blob, queue, table y file por cuenta; también dfs para `sapocidatafactorycr`, la única cuenta con HNS explícito en el origen. Un endpoint dfs no sustituye al de blob. Se conservan los diez destinos y se agrega un host dedicado de auditoría porque el exportado no identifica su Storage de host. Las asociaciones de host propuestas deben cotejarse con los app settings recuperados.
- Host de Functions mediante identidad administrada y roles de datos Blob/Queue/Table sobre su cuenta. No se copian claves. Los planes Linux dedicados no configuran Azure Files como contenido: el endpoint file deja preparada la conectividad, pero **no configura shares, montajes ni autenticación SMB**. Si el código recuperado depende de ellos hay que resolver ese requisito antes de activar; Shared Key está deshabilitado.
- Cosmos conserva las tres cuentas serverless y las seis bases SQL observadas; no inventa contenedores ni claves de partición. Cosmos, Search y servicios cognitivos usan acceso privado y deshabilitan autenticación local. Los permisos de negocio deben recuperarse y asignarse por identidad y recurso antes de ejecutar aplicaciones.
- Databricks Premium con dos subredes delegadas, `enableNoPublicIp=true`, `NoAzureDatabricksRules` y endpoint `databricks_ui_api`. El workspace administrado anterior no se intenta convertir en el sitio.
- Data Factory nuevo con VNet administrada, Integration Runtime y solicitudes de endpoints administrados a Storage de datos/riesgo y Databricks. No se crean pipelines, linked services ni triggers inexistentes en el exportado.
- Automation privado, sin copiar trabajos, calendarios ni ejecuciones. Se crean los endpoints de Hybrid Worker y webhook; todavía se debe proporcionar un **Hybrid Runbook Worker** conectado y restaurar allí los runbooks. Un endpoint privado no introduce los trabajos cloud dentro del spoke.
- Communication Services y un dominio de correo administrado nuevos, con remitente distinto al actual. Requieren revisar el envío y las autorizaciones antes del cambio de entorno.

## Contrato de conectividad con CAF

| Conexión | Configuración del spoke | Requisito de plataforma / aceptación |
|---|---|---|
| Clientes CAF → web y Functions | PE `sites`, acceso público cerrado | VPN/ExpressRoute/ruta desde la red cliente; resolver tanto `<app>.azurewebsites.net` como `<app>.scm.azurewebsites.net` a IP privada |
| Apps → Storage | Integración VNet y PE de cada servicio | Resolver blob/queue/table; probar operaciones con la identidad del host. SMB 445 sólo si se diseña un montaje real |
| Apps/Databricks → Cosmos | PE `Sql` | Gateway usa 443; Direct puede necesitar todo el rango TCP privado, no sólo 443 |
| Commons → ACR | PE `registry`, `AcrPull`, image pull por VNet | DNS de login y endpoint regional de datos; imagen existente y digest validado |
| Databricks → control y datos | SCC sin IP pública y PE UI/API | DNS privado, reglas delegadas de Databricks, salida aprobada para sus dependencias y Storage administrado |
| Navegador → Databricks | Reutilizar autenticación privada regional | CAF confirma `browser_authentication` existente y resoluble; crear uno sólo con aprobación de exclusividad regional/zona |
| ADF IR → Storage/Databricks | Managed private endpoints | Aprobar conexiones en destinos; configurar linked services para usar este IR y otorgar permisos de datos/Unity Catalog |
| Automation → servicios privados | PE para JRDS/webhook | Hybrid Worker real, extensiones y permisos; cloud jobs no acceden a estos datos privados |
| Apps → correo, Entra y APIs externas | Ruta por defecto al firewall | Lista de destinos/puertos aprobada por CAF; ACS Email requiere revisar la salida pública autenticada |
| Resolución DNS | Servidores corporativos en la VNet | TCP/UDP 53 accesible, reenvío al resolver de Azure y zonas centrales enlazadas a la VNet del resolver |

**DNS pertenece a CAF:** este spoke no crea zonas ni grupos DNS. La política central DINE debe crear los grupos/records y cubrir todos los tipos desplegados. Si una zona no está cubierta, CAF debe configurar su grupo; que un PE aparezca `Approved` no demuestra que DNS funcione. Esperar la remediación antes de probar los servicios.

Zonas a comprobar en el DNS central:

- `privatelink.blob.core.windows.net`, `privatelink.dfs.core.windows.net`, `privatelink.queue.core.windows.net`, `privatelink.table.core.windows.net`, `privatelink.file.core.windows.net`.
- `privatelink.azurewebsites.net` (incluye registros de SCM).
- `privatelink.azurecr.io` (login y datos regionales), `privatelink.documents.azure.com`, `privatelink.search.windows.net`.
- `privatelink.openai.azure.com`, `privatelink.cognitiveservices.azure.com`, `privatelink.azuredatabricks.net`.
- `privatelink.datafactory.azure.net`, `privatelink.adf.azure.com`, `privatelink.azure-automation.net`.

El peering **hub → spoke** es responsabilidad de CAF y debe permitir acceso y tráfico reenviado. Activar `useRemoteGateways` únicamente si el hub tiene gateway y `allowGatewayTransit`; el comprobador exige esa confirmación. El peering no aporta tránsito automático hacia otros spokes: dependencias compartidas requieren rutas explícitas de ida/vuelta por el hub o conectividad aprobada.

La UDR `0.0.0.0/0` controla la salida general; **no fuerza el tráfico a private endpoints por el firewall**. Los PE usan la ruta privada local y políticas NSG; la subred de PE no tiene UDR. Si CAF exige inspección entre workloads o de PE, debe definir rutas específicas simétricas y revisar los NSG, incluyendo los puertos de Cosmos Direct. Las reglas predeterminadas permiten tráfico desde redes conectadas; esto no es microsegmentación por aplicación.

La VNet administrada de ADF **no pertenece al spoke ni hereda su UDR/firewall**. Sus MPE son distintos de los PE de entrada de la factoría. Si CAF exige toda la salida de ADF por su firewall, se debe escoger SHIR en red CAF y adaptar los linked services en lugar de activar este IR administrado. Search tampoco hereda la integración de las apps: sus indexadores privados necesitan shared private links y permisos, pendientes porque no se exportaron sus definiciones.

## IPAM y parámetros

Solicitar un CIDR RFC1918 libre, sin solapamientos con hub, on-premises y demás spokes. Como reserva inicial, un /21 permite acomodar ocho subredes /24; no es una asignación aprobada. El comprobador requiere PE /24, cinco subredes de apps /26 o mayores y dos de Databricks /26 o mayores. Dimensionar Databricks según nodos; Azure reserva cinco IP por subred. Se generan 63 PE base (64 con browser auth), algunos con más de una IP, por lo que no se usa un /26 para PE.

Copiar `main.parameters.example.json` y `platform.example.json` a archivos locales. Sustituir los marcadores por datos aprobados, escoger un prefijo nuevo y declarar todos los rangos conectados. Los booleanos de plataforma son una confirmación humana, no una verificación contra Azure. No poner secretos en archivos versionados; `applicationSettings` es un parámetro seguro y está vacío por defecto.

```bash
python3 infra/idatafactory-spoke/check_parameters.py /ruta/parametros.json /ruta/plataforma.json
python3 infra/idatafactory-spoke/test_contracts.py
```

El comprobador rechaza marcadores, solapamientos, rangos no RFC1918, subredes insuficientes, DNS vacío, IP de firewall/DNS fuera de redes declaradas, IDs inválidos, digest de imagen ausente y requisitos CAF pendientes. Usarlo antes de un `what-if`; no sustituye la revisión del despliegue en Azure. No hay comando de creación automática.

## Cobertura y recuperación pendiente

| Recursos exportados | Tratamiento |
|---|---|
| Recursos principales, planes y seis sitios | Reconstruidos como destinos nuevos; el mapa Storage se publica como output |
| Servicios Storage, contenedores y tablas | Servicios disponibles en cuentas nuevas; no se recrean tablas históricas de diagnóstico ni contenedores internos de Functions. Recuperar datos, shares y configuración de retención/replicación requerida antes de migrar |
| Seis bases SQL | Nombres conservados en `cosmos-databases.json`; contenedores, índices, particiones y RBAC de negocio no estaban completos |
| Cuatro despliegues OpenAI | Inventariados abajo; no se consumen cuotas automáticamente. Recuperar despliegues tras confirmar disponibilidad, versión, SKU y capacidad; no hay Foundry ni agentes |
| Políticas RAI y roles integrados | No se recrean definiciones integradas exportadas. Revisar la política corporativa aplicable |
| Historial de deployments, Functions hijas, hostname bindings y scope maps integrados | Omitidos como estado generado; publicar desde el código/artefactos originales |
| Automation: jobs, módulos/runtime packages, schedules, jobSchedules y runbooks | No se reproducen jobs históricos ni dependencias de ejecución antiguas. Recuperar código y dependencias compatibles del worker; programaciones quedan sin activar |
| Event Grid system topic + webhook | No se recrea una entrega sin URL de destino. Filtro observado: `datasintetica/ejecuciones/`, sufijo `.json`, `BlobCreated`, tamaño mayor que cero; recuperar la suscripción completa |
| Data Factory y recursos que fallaron al exportar | Sólo se crea la base privada nueva; recuperar definiciones reales antes de cutover |

Despliegues OpenAI observados (inventario, **no recomendación de disponibilidad actual**):

| Nombre usado por aplicaciones | Modelo / versión exportada | SKU / capacidad |
|---|---|---|
| `gpt-4o` | `gpt-5.1` / `2025-11-13` | Standard / 100 |
| `gpt-4o-2` | `gpt-4o` / `2024-08-06` | GlobalBatch / 40271 |
| `gpt-4o-3` | `gpt-4o` / `2024-11-20` | GlobalStandard / 10 |
| `text-embedding-3-small` | `text-embedding-3-small` / `1` | Standard / 120 |

Atención: el deployment llamado `gpt-4o` apunta a `gpt-5.1`. No renombrarlo ni sustituir el modelo por deducción. El runtime Python 3.9 del procesamiento también se conserva como dato del origen, parametrizado; validar su soporte y compatibilidad antes de provisionar esa app. La réplica Search única y Storage LRS son bases iniciales; acordar disponibilidad y recuperación, no asumir equivalencia de SLA.

Event Grid Basic no entrega directamente por un PE al webhook privado. Si el destino recuperado era ADF, reconstruir el trigger ADF y su suscripción administrada; si era una Function, acordar un puente compatible o un cambio de consumidor. Un puente mediante colas requiere revisar identidad y excepciones de red del destino; no se habilita `AzureServices` indiscriminadamente.

## Verificación antes de activar

1. Obtener confirmación de IPAM, peering de retorno, DNS/DINE y reglas de firewall; resolver el modelo de ejecución ADF con CAF.
2. Ejecutar preflight y `what-if` sobre un **grupo de recursos nuevo**, revisar región, cuota, SKUs, costes y disponibilidad de runtimes. Evitar modo Complete o nombres del entorno actual.
3. Tras desplegar, comprobar ambos peerings `Connected`, rutas efectivas, PE `Approved`, grupos DNS y ausencia de resolución pública para todos los FQDN privados. Aprobar MPE de ADF por separado.
4. Recuperar código, app settings sin claves incrustadas, imágenes, modelos, Search, contenedores Cosmos/Storage, runbooks y artefactos ADF. Configurar identidades, roles de negocio, Unity Catalog y autenticación de usuarios. El Bicep asigna sólo host Storage y AcrPull; las demás identidades se exponen como outputs para conceder permisos justificados.
5. Desde una máquina conectada, cada app y un cluster Databricks, probar DNS, conexión TLS y una operación real autenticada en cada dependencia. Probar ADF desde su propio IR. Un 401/403 demuestra como máximo alcance HTTP, no acceso funcional.
6. Verificar la descarga real de Commons desde el ACR nuevo, Storage de Functions, acceso web/SCM y login Databricks; confirmar que clientes externos no tienen acceso al plano de datos privado. Comprobar envío de correo autorizado y recepción de eventos de extremo a extremo.
7. Activar aplicaciones y trabajos deliberadamente; cambiar consumidores sólo tras aceptación. Mantener los recursos anteriores y el procedimiento de retorno. No copiar triggers activos ni eliminar datos del origen.

## Fuentes de conectividad consultadas

- [Integración VNet de App Service](https://learn.microsoft.com/en-us/azure/app-service/overview-vnet-integration) y [private endpoints de App Service](https://learn.microsoft.com/en-us/azure/app-service/networking/private-endpoint).
- [Redes de Functions](https://learn.microsoft.com/en-us/azure/azure-functions/functions-networking-options) y [Storage del host mediante identidad](https://learn.microsoft.com/en-us/azure/azure-functions/functions-identity-based-connections-tutorial). Si se recuperan Blob triggers, revisar además Storage Account Contributor y los roles de cada extensión.
- [Private Link de Databricks](https://learn.microsoft.com/en-us/azure/databricks/security/network/concepts/privatelink-concepts) y [delegación VNet/NSG](https://learn.microsoft.com/en-us/azure/databricks/security/network/classic/vnet-inject).
- [Modos de conexión Cosmos](https://learn.microsoft.com/en-us/azure/cosmos-db/sdk-connection-modes).
- [VNet administrada ADF](https://learn.microsoft.com/en-us/azure/data-factory/managed-virtual-network-private-endpoint).
- [Limitaciones de Automation Private Link](https://learn.microsoft.com/en-us/azure/automation/how-to/private-link-security).
- [Entrega Event Grid con identidad](https://learn.microsoft.com/en-us/azure/event-grid/deliver-events-using-managed-identity).
