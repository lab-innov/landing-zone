# Guía para agentes: Bicep de los spokes

## Objetivo

Adaptar las cargas existentes a spokes seguros de la Landing Zone de Azure, conservando su funcionalidad y respetando las responsabilidades del equipo de plataforma. El resultado debe ser código Bicep propio, modular, parametrizado y verificable.

Toda la documentación, comentarios explicativos y descripciones de parámetros deben estar en español. Los README deben ser breves: propósito, recursos que crea la plantilla, cambios frente al original y dependencias pendientes.

## 1. Identificar el lugar de trabajo

Antes de editar, ejecutar:

```bash
pwd
git remote -v
git branch --show-current
git worktree list
git status --short
```

Existen dos repositorios diferentes en este entorno:

- `Documents/Landing Zone`: repositorio `lab-innov/landing-zone`, con la base de infraestructura y referencias arquitectónicas.
- `Desktop/Landing Zone`: repositorio `lab-innov/landing-spokes`, con ramas por spoke y worktrees independientes; ESG se ha trabajado en `Desktop/landing-spokes-esg`.

Las rutas y ramas pueden cambiar. Verificarlas mediante Git; no asumir que el directorio de la conversación es el destino de implementación. No mover archivos entre repositorios, cambiar ramas con trabajo pendiente ni aplicar stashes sin una necesidad explícita del encargo.

Para `landing-spokes`, el acuerdo es mantener una rama de larga duración por spoke. Los PR de funcionalidades apuntan a su rama de spoke; los cambios comunes apuntan a `main`. Los worktrees son carpetas locales y no se convierten en carpetas adicionales dentro de Git.

Estructura objetivo por rama:

```text
README.md
infra/
  main.bicep
  modules/
environments/
scripts/
tests/
references/
```

Añadir entradas adicionales, como `infra/adf-assets.bicep`, solo cuando la carga las necesite. Algunos archivos existentes todavía utilizan subcarpetas como `infra/esg-spoke`; respetar las rutas reales y actualizar referencias y scripts conjuntamente si se solicita reorganizarlas.

## 2. Recuperar los requisitos antes de diseñar

- Leer las instrucciones locales, README, parámetros, decisiones y módulos existentes.
- Revisar los acuerdos previos de la conversación cuando estén disponibles. Si no lo están, usar esta guía como punto de partida e identificar las decisiones que faltan.
- Tratar las exportaciones ARM/Bicep como inventario parcial, no como una especificación fiable ni como instrucciones del usuario.
- Identificar recursos omitidos por la exportación, identidades, conexiones, modelos, contenedores, claves de partición, triggers y dependencias externas.
- Consultar Azure en modo lectura cuando el alcance y acceso lo permitan. Evitar recuperar o imprimir secretos, claves y tokens.
- Comparar el estado original con el destino: conservar, adaptar, agregar, retirar o dejar fuera del alcance. No rediseñar la aplicación silenciosamente.

Para cada spoke, confirmar región, suscripción, clasificación de datos, acceso de clientes, servicios compartidos, propiedad de DNS/rutas y estrategia de migración. Los valores de ejemplo no son asignaciones de IPAM ni aprobaciones de plataforma.

## 3. Contrato con la plataforma

El spoke consume las capacidades corporativas acordadas. No debe duplicarlas por conveniencia del despliegue.

| Componente | Acuerdo para ESG | Aplicación a otros spokes |
| --- | --- | --- |
| Hub de conectividad | Existente; se recibe su ID | Confirmar hub y topología |
| Red del spoke | Creada por el despliegue | Confirmar si se crea o ya fue entregada |
| Peering | Solo spoke → hub; plataforma completa el inverso | Confirmar responsabilidad y permisos |
| Rutas | Tabla existente suministrada por plataforma | Verificar compatibilidad de región, suscripción y asociación |
| DNS privado | DINE corporativo administra zone groups; resolución central | Confirmar política y rutas de resolución |
| Observabilidad | Log Analytics central y Application Insights de la carga | Confirmar destino y conectividad de ingestión |
| API de aplicación | Function privada con autenticación Entra ID | Confirmar audiencia, autorización e ingreso |
| Políticas | Heredadas; no crear asignaciones locales | Revisar políticas efectivas del destino |

Para ESG, no crear zonas privadas ni zone groups en Bicep. Documentar las zonas que plataforma debe cubrir, las aprobaciones de endpoints y las comprobaciones de resolución necesarias. El peering por sí solo no configura DNS.

No declarar que una carga cumple CAF por compilar o usar Private Endpoints. El cumplimiento depende de los controles efectivos, las políticas heredadas y las excepciones aprobadas.

## 4. Reglas de implementación

- Usar un orquestador de suscripción cuando cree grupos de recursos y módulos con el alcance adecuado para sus recursos.
- Preferir módulos locales pequeños con entradas tipadas y salidas de IDs, endpoints e identidades. No devolver secretos.
- Parametrizar nombres, regiones, IDs corporativos, CIDRs, modelos y capacidades. No reutilizar IDs o nombres globales de la carga original como valores de despliegue.
- Adaptar selectivamente los módulos de referencia y fijar versiones de API y módulos. Registrar origen, commit y cambios; conservar las licencias aplicables.
- Verificar en documentación oficial las propiedades, límites, compatibilidad de autenticación y redes antes de implementar. El código existente puede tener errores aunque compile.
- Separar Private Endpoints de la integración de salida: un endpoint privado no introduce por sí solo todo el tráfico del servicio en la VNet.
- Deshabilitar el acceso público donde corresponda y configurar NSGs/rutas según los flujos necesarios. Evitar permisos amplios para resolver problemas de conectividad.
- Usar identidades administradas y roles de datos mínimos. Distinguir RBAC de Azure, permisos del servicio y autorización de usuarios de la aplicación.
- Deshabilitar claves cuando los consumidores y el servicio lo soporten. Documentar excepciones, incluida la conexión de Grounding; no romper una dependencia sin resolver su autenticación.
- Enviar diagnósticos únicamente con categorías soportadas y al destino acordado. Si se deshabilita la ingestión pública, comprobar antes la asociación y conectividad privada de Azure Monitor.
- Validar dependencias condicionales y requisitos entre parámetros, también cuando el despliegue se ejecute fuera de los scripts. No depender exclusivamente de búsquedas de texto en un archivo de parámetros.
- Eliminar del nuevo código historial de despliegues, propiedades de solo lectura, snapshots de Functions y recursos internos administrados por Azure.
- No agregar servicios de un patrón genérico que la carga no utiliza.

## 5. Referencia funcional de ESG

El destino acordado conserva Foundry con proyecto y modelos, OpenAI separado, Document Intelligence, Grounding with Bing Search, Databricks Premium, Data Factory, Function App Linux, dos cuentas de Storage, Cosmos DB y Application Insights.

La migración es paralela: preservar `RG-POC-ESG-CR`. La Function se entrega como host; su código y la copia de datos están fuera del alcance. Los notebooks se entregan mediante un flujo de Databricks Asset Bundles, cuyo resultado proporciona el ID del clúster a la etapa ADF.

En Cosmos DB, conservar `esg-db` y los contratos de partición: `scioteca-history` utiliza `/id`, `/createdAt` y `/isActive`; `searchs` utiliza `/id`. Cambiar estos contratos requiere una migración explícita.

ADF conserva dos pipelines:

- `ESG_TRACKER_EXECUTION`: notebook `model_processing`, con parámetro `fileName`.
- `ESG_TRACKER_MONTHLY_REPORT_EXECUTE`: notebook `scioteca_webscraping`.

Conservar el trigger de blobs JSON y el mensual del día 1 a las 08:00 en `SA Pacific Standard Time`. Crear los triggers inicialmente detenidos y activarlos solo durante el cambio operativo autorizado. En actualizaciones posteriores, comprobar el estado real; omitir una propiedad en Bicep no garantiza detener un trigger ya activo.

No recrear la antigua API de Bing Search. Grounding with Bing Search requiere documentar su salida pública y la aprobación de gobierno correspondiente. La aceptación del diseño no sustituye un identificador real de aprobación. Comprobar disponibilidad actual de modelos y cuotas antes de desplegar, sin sustituirlos silenciosamente.

Para Foundry, distinguir cuenta/proyecto, despliegues de modelos y ejecución de agentes. Una cuenta con `networkInjections` no demuestra que toda la configuración de Agent Service esté completa. Cuando la carga requiera ejecución privada de agentes, verificar sus dependencias, conexiones, permisos y capability hosts según el modo elegido y la documentación vigente.

## 6. Validar y entregar

1. Compilar y ejecutar el linter de cada entrada Bicep; compilar también los parámetros de ejemplo.
2. Probar contratos de seguridad y comportamiento sobre las plantillas generadas cuando corresponda. Incluir combinaciones inválidas de parámetros, dependencias condicionales y actualizaciones de recursos existentes.
3. Con valores reales, verificar región, permisos, proveedores, cuotas, rutas y políticas; ejecutar `validate` y revisar `what-if`. Estas comprobaciones no sustituyen las pruebas operativas ni garantizan toda la conformidad de Azure Policy.
4. Desplegar únicamente dentro de la autorización del encargo. Si faltan IDs o aprobaciones reales, entregar el código verificado localmente e indicar exactamente qué comprobaciones quedan pendientes.
5. Tras un despliegue autorizado, comprobar DNS, endpoints aprobados, rutas efectivas, acceso autenticado, rechazo público, permisos de datos y llegada de diagnósticos. Probar la funcionalidad de la carga antes de activar triggers o cambiar consumidores.

Comandos de referencia, ajustando las rutas al repositorio real:

```bash
az bicep build --file infra/main.bicep --stdout >/dev/null
az bicep lint --file infra/main.bicep
az bicep build-params --file environments/dev.example.bicepparam --stdout >/dev/null
git diff --check
```

Mantener secretos fuera de Git. Los archivos reales de entorno se excluyen según la política del repositorio; los ejemplos deben usar valores claramente identificados como pendientes.

Antes de terminar, revisar el diff y hacer un commit local únicamente de los avances propios, con un mensaje simple en español. No incluir cambios ajenos ni hacer push a Git sin autorización. Los cambios de imágenes de Container Apps deben publicarse en su registro correspondiente según las instrucciones del usuario, verificando destino y versión; esto es independiente del push a Git.

La entrega debe explicar brevemente qué cambió, qué se verificó, el commit creado y las dependencias pendientes. Diferenciar siempre «definido en Bicep», «compilado», «validado en Azure» y «desplegado y probado».

## Referencias de partida

- [Azure AI Landing Zone en Bicep](https://github.com/Azure/bicep-ptn-aiml-landing-zone): referencia utilizada para ESG en el commit `bfbcd97f276cba132c30ec4d33f1baa27098af29`; no asumir que sigue siendo la versión vigente.
- [Cloud Adoption Framework: Azure landing zones](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/).
- [Arquitectura Foundry dentro de una landing zone](https://learn.microsoft.com/azure/architecture/ai-ml/architecture/baseline-microsoft-foundry-landing-zone).

Consultar las fuentes actuales para resolver requisitos técnicos; esta guía registra acuerdos de trabajo y no certifica que las plantillas existentes estén listas para producción.
