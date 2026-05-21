# Variables de ejemplo para el AI Governance Hub

Este directorio contiene una plantilla mínima de variables para desplegar el hub de gobernanza con `azd`.

Archivo base:

- `citadel-hub.env.example`

Uso sugerido:

```bash
cp environments/citadel-hub/citadel-hub.env.example environments/citadel-hub/citadel-hub.env
./scripts/azd-citadel-hub.sh environments/citadel-hub/citadel-hub.env provision
```

Si se quiere desplegar también la lógica de ingestión:

```bash
./scripts/azd-citadel-hub.sh environments/citadel-hub/citadel-hub.env up
```
