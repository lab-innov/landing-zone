# Orden de despliegue recomendado

## 1. Validar prerrequisitos de plataforma

- suscripciones y permisos;
- CIDRs sin solapamiento;
- ownership de Private DNS Zones;
- ownership del firewall y de las route tables;
- proveedores de recursos registrados.

## 2. Connectivity Hub corporativo

Este repositorio no despliega el hub corporativo de conectividad. Se asume existente o gestionado por plataforma.

Debe existir como mínimo:

- VNet hub;
- firewall o NVA;
- DNS privado compartido si se va a reutilizar;
- conectividad a on-premises si aplica.

## 3. Desplegar el AI Governance Hub

Ruta:

`infra/hub-governance`

Script:

```bash
./scripts/deploy-hub-governance.sh environments/hub-governance/hub-governance.env create
```

## 4. Desplegar el primer Spoke Base

Ruta:

`infra/spoke-base`

Script:

```bash
./scripts/deploy-spoke-base.sh environments/spoke-base/spoke-base.env create
```

## 5. Completar integración con el hub corporativo

El spoke base puede crear el peering **spoke → hub**.

El peering **hub → spoke** sigue siendo responsabilidad del equipo de plataforma o de una automatización posterior, porque normalmente vive en otro scope operativo.

También deben cerrarse:

- UDR hacia el firewall del hub;
- linking a zonas DNS privadas compartidas;
- validación de reachability entre subredes necesarias.

## 6. Validación final

- despliegue subscription-scope correcto;
- recursos principales creados;
- private endpoints creados si fueron habilitados;
- peering spoke → hub creado si se configuró;
- resolución DNS privada según el modelo elegido.
