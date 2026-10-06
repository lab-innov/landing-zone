# Gateway de IA

Punto de acceso privado a Azure OpenAI con autenticación corporativa y límites por iniciativa. APIM es el servicio que desempeña la función de AI Gateway.

- `main.bicep`: configura rutas de chat en un APIM existente.
- `foundation.bicep`: prepara opcionalmente un APIM Standard v2 nuevo, su endpoint privado y diagnósticos centrales.
- `backend-access.bicep`: concede acceso de inferencia a la identidad de APIM sobre una cuenta existente.

Base propia inspirada en el acelerador de Microsoft. No instala el acelerador completo ni modifica el hub anterior. Requiere redes, DNS, modelos e identidades aprobados por CAF.

Consultar la guía de despliegue en [Word](../../docs/guia-despliegue-ai-gateway.docx) o [Markdown](../../docs/guia-despliegue-ai-gateway.md).
