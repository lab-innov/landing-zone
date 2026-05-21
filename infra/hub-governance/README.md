# Hub Governance

Código Bicep propio para el **hub de gobernanza de IA**.

Incluye:

- red dedicada;
- API Management;
- AI Foundry / AI Services;
- Log Analytics y Application Insights;
- Key Vault, Storage, Event Hub y Cosmos DB;
- Private DNS Zones y private endpoints opcionales.

Despliegue:

```bash
./scripts/deploy-hub-governance.sh environments/hub-governance/hub-governance.env create
```
