# Foundry Agent privado para CAF

Plantilla propia para **un workload `foundry-agent`**. Sustituye la idea inicial de
tres perfiles según la aclaración de alcance. Application Gateway es privado y la
persistencia de Foundry Standard se despliega en la suscripción CAF. No modifica
los perfiles anteriores ni despliega Azure automáticamente.

## Base común para agentes con o sin RAG

El patrón y la rama de trabajo son `foundry-agent`. No se mantiene una variante
separada `foundry-rag`: ambos casos reutilizan esta base de red, cómputo y
persistencia Standard. Esta plantilla configura la infraestructura; la versión
actual no activa recuperación documental en la aplicación.

Para incorporar RAG se agregan los índices de documentos y su ingestión,
extracción y fragmentación, un modelo de embeddings si se usa búsqueda vectorial,
y la herramienta del agente que consulta el índice. Ajustar los permisos del
indexador/backend y su conectividad privada según quién realice la ingestión y
consulta. Puede reutilizarse el servicio Search con un índice de aplicación
separado de los índices administrados por Foundry. Un proceso de ingestión en
segundo plano puede requerir un Job adicional.

## Recursos incluidos

| Componente | Implementación |
| --- | --- |
| Red | VNet nueva, seis subredes, NSG y rutas al firewall del hub CAF |
| Conectividad | Peering spoke → hub; el equipo CAF administra el peering inverso |
| Foundry | Cuenta AIServices, proyecto con identidad, conexiones AAD y capability host Standard |
| Persistencia Foundry | Storage exclusivo, Cosmos DB y Azure AI Search privados |
| Blob de aplicación | Otra cuenta Storage, contenedor `uploads`, versiones y recuperación de 14 días |
| Aplicación | Un entorno Container Apps interno con workload profiles; frontend y backend separados |
| Registro | ACR Premium privado, administrador deshabilitado y descarga mediante identidad |
| Secretos | Key Vault privado con RBAC, soft delete y protección contra purga |
| Entrada | Application Gateway WAF_v2 privado, HTTPS, TLS mínimo 1.2, certificado de Key Vault |
| Identidades | Identidades separadas para frontend, backend y gateway; identidad propia del proyecto |
| Observabilidad | Log Analytics, Application Insights y diagnósticos de Application Gateway |
| Modelos | Despliegues opcionales; versión, modalidad y capacidad explícitas por modelo |
| Endpoints privados | Foundry, ambos Storage Blob, Key Vault, ACR, Cosmos DB y Search |

**Sin RAG no equivale a Foundry Basic.** El servicio Standard utiliza Storage,
Cosmos DB y Search como dependencias propias. La aplicación no crea índices RAG,
pipelines de ingestión, embeddings ni herramientas `file_search`. Las conexiones
del capability host apuntan a recursos CAF; no se usa la variante Basic con
persistencia administrada por Microsoft. Esta decisión sigue el
[ejemplo oficial Standard](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep/15-private-network-standard-agent-setup)
y la [guía de red privada](https://learn.microsoft.com/azure/foundry/agents/how-to/virtual-networks).

La cuenta Blob de aplicación es independiente de la de Foundry. El backend tiene
Blob Data Contributor solo sobre `uploads`. La identidad del proyecto tiene Blob
Data Owner sobre su cuenta exclusiva, Cosmos DB Operator y permisos de datos
sobre `enterprise_memory`, más los dos roles de Search requeridos. Ese alcance
sobre la cuenta de Storage permite al servicio crear sus contenedores; no
compartir esa cuenta con otros proyectos o datos de aplicación.

## Red y restricciones CAF

Todos los CIDR, DNS y destinos del hub son obligatorios y deben venir de IPAM.
No se asignan rangos reales de CAF ni se modifica una VNet existente.

| Clave de `prefixes` | Subred | Tamaño de planificación |
| --- | --- | --- |
| `vnet` | Espacio total | Dimensionar para las seis subredes sin solapamiento |
| `foundry` | `snet-foundry` | /24 recomendado; exclusiva de esta cuenta Foundry |
| `containers` | `snet-containers` | /23 como reserva de crecimiento; entorno workload profiles admite /27 mínimo |
| `appGateway` | `snet-appgateway` | /24 recomendado |
| `privateEndpoints` | `snet-private-endpoints` | /26 o mayor |
| `gateway` | `GatewaySubnet` | /27 o mayor, reserva sin VPN/ExpressRoute local |
| `firewall` | `AzureFirewallSubnet` | /26 o mayor, reserva sin firewall local |

Hay seis subredes porque **Application Gateway no utiliza `GatewaySubnet`**.
Foundry y Container Apps tienen delegaciones independientes a
`Microsoft.App/environments`; el gateway privado tiene delegación a
`Microsoft.Network/applicationGateways`. Las reservas de firewall y VPN se
incluyen por la solicitud; CAF puede eliminarlas en una variante futura si ambos
servicios siempre pertenecen al hub.

La tabla de rutas fuerza la salida de Foundry, ACA y Application Gateway hacia el
firewall central. Los NSG de Foundry/ACA son una base con las reglas Azure
predeterminadas; no representan microsegmentación completa. El NSG del gateway
solo admite HTTPS desde los CIDR CAF y sondas AzureLoadBalancer. El frontend
restringe su entrada a la subred del gateway y el backend solo admite tráfico
desde el mismo entorno ACA.

CAF debe configurar el peering inverso, propagación de rutas y gateway transit.
En una VNet nueva, comenzar con `useRemoteGateways=false`, preparar el peering del
hub y después activar `true` si hay tránsito VPN/ExpressRoute. El firewall debe
permitir DNS, Entra ID, dependencias de ACA/Foundry, registro y monitorización.
Las APIs externas usadas por herramientas necesitan reglas explícitas y revisión
de soporte de red privada. No se alteran las reglas del firewall corporativo.

El frontend debe actuar como proxy del backend usando `BACKEND_URL`; un navegador
no puede llamar directamente al backend interno. Validar que las imágenes
implementen este contrato, autenticación Entra ID y autorización de usuarios.
La infraestructura y WAF no implementan el inicio de sesión de la aplicación.

## DNS

El valor predeterminado `privateDnsMode='policy'` **no crea zonas ni grupos DNS**:
espera que DINE central los asocie a los endpoints. La creación del endpoint no
prueba que DINE haya terminado. Antes de activar el runtime verificar resolución
desde la VNet. Si CAF administra las asociaciones explícitamente, usar `existing`
y rellenar `privateDnsZoneIds` con arrays de IDs centrales:

| Clave | Zona |
| --- | --- |
| `foundry` | Las tres: `privatelink.cognitiveservices.azure.com`, `privatelink.openai.azure.com`, `privatelink.services.ai.azure.com` |
| `blob`, `agentBlob` | `privatelink.blob.core.windows.net` |
| `vault` | `privatelink.vaultcore.azure.net` |
| `acr` | `privatelink.azurecr.io` |
| `cosmos` | `privatelink.documents.azure.com` |
| `search` | `privatelink.search.windows.net` |

Los DNS corporativos deben resolver esas zonas mediante enlaces y reenviadores.
El peering por sí solo no hace transitivos los enlaces de Azure Private DNS.

ACA usa un balanceador interno; no necesita un endpoint privado adicional para
el camino App Gateway → frontend. Crear en DNS central una zona con el output
`containerEnvironmentDomain` y registro `*` hacia `containerEnvironmentIp`.
`createContainerEnvironmentDns=true` permite crear esa zona localmente cuando
CAF delega esa responsabilidad; también requiere que los DNS configurados puedan
resolverla. Registrar `gatewayHostname` apuntando a `gatewayPrivateIp` en DNS CAF.

## Orden de preparación y despliegue

1. Copiar `main.parameters.example.json` a un archivo local fuera del repositorio.
   Reemplazar los marcadores con suscripción/RG, región y CIDR aprobados. El RG
   debe existir: la plantilla tiene alcance de grupo de recursos.
2. Compilar y comprobar los parámetros con los comandos siguientes. Ejecutar
   `validate` y `what-if` con el equipo CAF antes de desplegar; revisar políticas,
   cuotas, región, ZRS, roles y la creación de red. El operador necesita crear
   asignaciones de roles, además de recursos.
3. Desplegar la fundación con `activateAgentRuntime`, `deployApplications` y
   `deployGateway` en `false`. Crea servicios, identidades, endpoints, entorno ACA
   y observabilidad. Completar peering, firewall y DNS central.
4. Verificar DNS y propagación de RBAC desde una máquina conectada a CAF. Activar
   `activateAgentRuntime=true` para crear conexiones y capability host Standard.
   Configurar `models` con los modelos, versiones y capacidad autorizados o
   desplegarlos separadamente antes de ejecutar agentes. Un array vacío no crea
   modelos ni permite asumir que un agente ya funciona.
5. Construir y **publicar ambas imágenes en el ACR privado** desde un ejecutor
   con conectividad CAF y permiso de publicación. No se abre ACR a Internet para
   este paso. Usar el output `registryServer`; la identidad de publicación no es
   ninguna de las identidades de ejecución con AcrPull. Verificar arquitectura
   y contrato de variables, puertos y proxy de las imágenes seleccionadas.
6. Configurar `frontendImage`, `backendImage`, puertos y variables no secretas;
   activar `deployApplications=true`. Usar digest o etiquetas inmutables. Para
   secretos, implementar acceso a Key Vault mediante identidad; no incluir
   valores secretos en `frontendEnv`/`backendEnv` ni en archivos de parámetros.
7. Importar un certificado PFX válido con clave privada y cadena en el Key Vault
   creado. El nombre predeterminado es `appgateway-tls`. El operador debe tener
   permisos de importación y conectividad privada. La identidad del gateway
   obtiene lectura; la URI sin versión permite la renovación del certificado.
8. Confirmar el registro de `EnableApplicationGatewayNetworkIsolation` en la
   suscripción y DNS del dominio. Configurar IP, hostname y ruta de salud; activar
   `deployGateway=true`. No crea IP pública ni listener HTTP.
9. Mantener los indicadores activados en las siguientes ejecuciones. No usar
   indicadores en `false` como mecanismo de retirada o rollback: ARM incremental
   no borra recursos omitidos. Usar imágenes anteriores para rollback de apps.

Desde la raíz del repositorio (reemplazar RG, ruta y suscripción según CAF):

```bash
az bicep build --file infra/foundry-private/main.bicep --outfile /tmp/foundry-private.json
python3 infra/foundry-private/check_parameters.py /ruta/privada/parametros.json
az deployment group validate --resource-group RG_CAF --template-file infra/foundry-private/main.bicep --parameters @/ruta/privada/parametros.json
az deployment group what-if --resource-group RG_CAF --template-file infra/foundry-private/main.bicep --parameters @/ruta/privada/parametros.json
# Solo después de revisar el resultado y autorizar el despliegue:
az deployment group create --resource-group RG_CAF --template-file infra/foundry-private/main.bicep --parameters @/ruta/privada/parametros.json
```

El comprobador local detecta marcadores, solapamientos internos, redes fuera de
RFC1918, tamaños y combinaciones incompletas. No consulta IPAM, rutas del hub,
existencia de imágenes, certificados, modelos ni políticas. No sustituye Azure
`validate` ni `what-if`. Los permisos pueden tardar en propagarse aunque ARM
termine; no hay esperas artificiales ni scripts con credenciales en el Bicep.

## Recomendaciones y verificación pendiente

- **Monitorización privada:** Log Analytics y App Insights están en CAF, pero esta
  versión no despliega AMPLS ni deshabilita su ingestión pública. Reutilizar el
  AMPLS y DNS corporativos si CAF exige transporte privado de telemetría; mientras
  tanto se requiere salida autorizada por firewall. Las trazas del backend
  requieren instrumentación de la imagen. No se configura conexión de tracing
  del runtime Foundry en esta versión.
- **Operación:** añadir alertas y destinatarios CAF, presupuestos, retención
  definitiva, diagnósticos de auditoría de servicios de datos y pruebas de
  restauración. Las versiones Blob y backup continuo de Cosmos son una base,
  no un plan de recuperación completo.
- **Disponibilidad:** confirmar RTO/RPO y zonas. Search usa una réplica y el
  gateway capacidad mínima 1; la plantilla no garantiza alta disponibilidad
  zonal o recuperación multirregión. Ajustar capacidad a carga y SLA antes de
  producción. La región debe soportar Storage ZRS y red privada de Foundry.
- **Controles de aplicación:** Entra ID, autorización por usuario, pruebas WAF
  con archivos y streaming, límites de carga y retención de conversaciones.
  API Management solo si se necesita la gobernanza API central; no es necesario
  para el camino de entrada descrito.
- **Aceptación desde CAF:** comprobar DNS privado de todos los servicios,
  descarga ACR por identidad, lectura/escritura en `uploads`, creación y
  ejecución de un agente, persistencia en los recursos CAF, certificado HTTPS,
  salud del gateway, frontend → backend y rechazo del acceso directo al frontend
  desde otras subredes. Confirmar que el backend no sea accesible fuera de ACA.

Validación realizada localmente: compilación Bicep sin errores ni advertencias de
plantilla, y comprobaciones estáticas de parámetros y recursos. No se ejecutaron
`validate`, `what-if`, despliegues ni pruebas de red en Azure. No se construyeron
ni publicaron imágenes: aún no se eligieron imágenes, RG ni ACR reales.

Referencias: [landing zone de referencia fijada](https://github.com/Azure/bicep-ptn-aiml-landing-zone/tree/fb2f85074eb849be7df4109e516b9902b1f84fa6),
[gateway privado](https://learn.microsoft.com/azure/application-gateway/application-gateway-private-deployment),
[DNS de Container Apps](https://learn.microsoft.com/azure/container-apps/private-endpoints-with-dns).
