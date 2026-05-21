# Decisiones y supuestos

## Decisiones tomadas

1. El repositorio tendrá **código propio** como producto principal.
2. La estructura inicial será:
   - `infra/hub-governance`
   - `infra/spoke-base`
3. Cada despliegue tendrá **módulos locales dentro de su propia carpeta**.
4. Los repos de Microsoft quedan solo como **referencia** en `references/upstream-sources.json`.
5. El spoke base será el punto de partida para futuros patrones de POC.

## Supuestos

- el hub corporativo de conectividad existe o será gestionado por plataforma;
- este repo se enfoca en el hub de gobernanza y el spoke base;
- el peering inverso `hub → spoke` se resolverá fuera de esta primera automatización;
- luego se crearán otros patrones sin introducir una librería de módulos compartidos entre carpetas.

## Decisiones abiertas

- si APIM irá `External` o `Internal` por ambiente;
- si el hub de gobernanza tendrá DNS propio o reutilizará DNS corporativo;
- qué recursos serán obligatorios en el siguiente patrón de spoke;
- naming final y segmentación por suscripción.
