# Spoke Base

Código Bicep propio para el **spoke base** de una solución o POC.

Incluye:

- red del spoke;
- AI Foundry / AI Services;
- Log Analytics y Application Insights;
- Storage y Key Vault;
- AI Search, Cosmos DB y ACR opcionales;
- route table opcional;
- peering spoke → hub opcional;
- Private DNS Zones y private endpoints opcionales.

Despliegue:

```bash
./scripts/deploy-spoke-base.sh environments/spoke-base/spoke-base.env create
```
