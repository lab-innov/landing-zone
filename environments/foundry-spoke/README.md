# Variables de ejemplo para el Foundry Spoke

Este directorio contiene una plantilla base para desplegar el spoke de Foundry en modo integrado con landing zone corporativa.

Archivo base:

- `foundry-spoke.env.example`

Uso sugerido:

```bash
cp environments/foundry-spoke/foundry-spoke.env.example environments/foundry-spoke/foundry-spoke.env
./scripts/azd-foundry-spoke.sh environments/foundry-spoke/foundry-spoke.env provision
```
