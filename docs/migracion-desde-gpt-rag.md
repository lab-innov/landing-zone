# Migración conceptual desde GPT-RAG

## Resumen

`GPT-RAG` sigue siendo una referencia útil para una solución RAG, pero ya no es el molde estructural del repositorio.

Ahora el repositorio se orienta a:

- un **hub de gobernanza** propio;
- un **spoke base** propio;
- evolución posterior a otros patrones de spoke.

## Cambio de enfoque

Antes:

- referencia fuerte a aceleradores upstream;
- estructura pensada alrededor de repos externos;
- base útil para una sola solución o una primera iteración.

Ahora:

- código Bicep propio dentro de `infra/`;
- separación clara entre hub y spoke;
- diseño más cercano a plataforma reusable por POC.

## Qué queda como referencia

Los commits upstream siguen documentados en:

`references/upstream-sources.json`

Eso preserva trazabilidad sin convertir los repos externos en la estructura operativa del proyecto.

## Qué se gana

- ownership real del código;
- mayor libertad para crear patrones de spokes;
- revisión de Infra más clara;
- posibilidad de endurecer naming, RBAC y topología sin depender de reorganizar repos de terceros.
