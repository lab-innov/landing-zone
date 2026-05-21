# Decisiones y supuestos

## Decisiones ya tomadas en este repositorio

1. El patrón objetivo será **hub-hubs**:
   - hub corporativo de conectividad;
   - hub de gobernanza de IA;
   - spokes de Foundry por dominio.
2. El spoke de referencia se toma de `bicep-ptn-aiml-landing-zone`.
3. El hub de gobernanza se toma de `ai-hub-gateway-solution-accelerator`.
4. La referencia conceptual compuesta se toma de `AI-Landing-Zones`.
5. El código upstream queda **vendorizado** para evitar dependencia en tiempo de revisión.

## Supuestos

- el equipo de plataforma controla o aprobará el hub de conectividad;
- el equipo de IA necesita demostrar arquitectura y código, no ejecutar una migración en caliente;
- el primer despliegue será un entorno de validación;
- el patrón debe poder repetirse para más de un spoke.

## Decisiones que siguen abiertas

- suscripción final del AI Governance Hub;
- si APIM será interno en todos los ambientes;
- ownership final de Private DNS Zones;
- ownership de route tables y peerings reversos;
- naming corporativo;
- regiones definitivas y cuotas de modelos.
