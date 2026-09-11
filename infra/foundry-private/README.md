# Foundry Agent privado para CAF

Base en **East US**, con VNet **/24**, VPN del hub corporativo, DNS **CAF/DINE**,
agente administrado Foundry Standard y frontend/backend privados en Container Apps.
APIM se integra en una etapa posterior. No crea Bastion, VPN Gateway, firewall,
zonas/grupos DNS ni Log Analytics.

| Componente | Configuración |
| --- | --- |
| Red | Foundry /25, ACA /26, endpoints /27 y Application Gateway /27 |
| Foundry | AIServices S0, proyecto `agents`, identidad y persistencia exclusiva |
| Persistencia | Storage ZRS, Cosmos NoSQL zonal con backup continuo de 7 días, Search Standard con 3 réplicas |
| Aplicación | Storage `uploads` separado; ACA interno zonal; dos aplicaciones de 0,5 vCPU/1 GiB, 2-3 réplicas |
| Entrada | WAF_v2 privado zonal, 2-3 instancias, HTTPS y certificado de Key Vault |
| Seguridad | Identidades separadas, ACR Premium privado, Key Vault RBAC y protección contra purga |
| Operación | Application Insights privado, Log Analytics y Action Group existentes; diagnósticos y alertas |

El /24 queda completo: Foundry /25 está por debajo de la recomendación de
producción /24; Application Gateway /27 limita el crecimiento. La configuración
no demuestra un SLA compuesto ni capacidad suficiente para una carga no medida.
Search es persistencia del runtime: no se implementa RAG de aplicación.

## Validación local

```bash
./infra/foundry-private/validate.sh
python3 infra/foundry-private/check_parameters.py /ruta/privada/parametros.json
```

Copiar `main.parameters.example.json` fuera del repositorio y completar los
valores corporativos. Los marcadores se rechazan deliberadamente. Consultar
[preparación y despliegue](DESPLIEGUE.md) para DNS, rutas, etapas, pruebas y rollback.

Esta variante sustituye `prefixes`, `hubFirewallIp`, `privateDnsMode`,
`privateDnsZoneIds` y `createContainerEnvironmentDns` por `vnetPrefix`,
`routeTableIds` y DNS exclusivamente corporativo. Conserva los nombres de recursos
para el mismo RG y `workload`, pero **no debe aplicarse sobre subredes ocupadas**
para intentar reducirlas a /24. En ese caso requiere migración paralela.
