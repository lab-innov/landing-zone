# Migración conceptual desde GPT-RAG

## Resumen

`GPT-RAG` es una solución aceleradora muy útil para cargas RAG concretas, pero la arquitectura objetivo de este repositorio persigue otra meta: separar el plano de **gobernanza central** del plano de **ejecución por dominio**.

## Estado actual

Tomando `Azure/GPT-RAG` como referencia, el patrón actual tiende a agrupar:

- la red de la solución;
- los servicios de IA;
- las dependencias de aplicación;
- el gateway/perímetro de la carga;
- la lógica de solución.

Eso funciona bien para una implementación única o para un punto de partida de producto.

## Estado objetivo

El patrón objetivo desacopla esas responsabilidades:

- **Hub corporativo**: conectividad, firewall, Bastion, DNS, observabilidad compartida.
- **Hub de gobernanza de IA**: APIM, AI Gateway, contratos de acceso, uso, trazabilidad.
- **Spoke de Foundry**: una landing zone privada y repetible por caso de uso.

## Razones para el cambio

1. **Escalabilidad organizacional**
   - se pueden crear varios spokes sin duplicar el gateway de gobierno.
2. **Separación de responsabilidades**
   - plataforma maneja conectividad;
   - gobierno de IA maneja políticas y exposición;
   - equipos de producto consumen un spoke repetible.
3. **Aprobación de Infraestructura**
   - el patrón queda más alineado con ALZ, hub-spoke y ownership claro.
4. **Reutilización**
   - observabilidad, DNS privado y firewall pueden mantenerse centralizados.

## Mapeo de capacidades

| Necesidad | GPT-RAG | Patrón objetivo |
| --- | --- | --- |
| RAG / app acelerada | fuerte | secundario |
| landing zone repetible por spoke | parcial | fuerte |
| gobierno central de tráfico IA | parcial | fuerte |
| APIM como AI Gateway | no es el centro del patrón | sí |
| topología multi-spoke | limitada | nativa |
| integración con hub corporativo | posible, pero no es el eje | nativa |

## Impacto práctico

La migración no implica “tirar” `GPT-RAG`, sino cambiar el punto de partida:

- `GPT-RAG` pasa a ser una referencia de solución o workload;
- `bicep-ptn-aiml-landing-zone` pasa a ser la base del spoke;
- `ai-hub-gateway-solution-accelerator` pasa a ser la base del hub de gobernanza.

## Recomendación

Para aprobación arquitectónica, conviene presentar `GPT-RAG` como “lo que hoy resuelve una solución puntual” y este repositorio como “la base de landing zone corporativa para varias soluciones”. 
