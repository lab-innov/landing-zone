# Orden de despliegue recomendado

## 1. Validar prerrequisitos de plataforma

Antes de tocar los aceleradores:

- confirmar suscripciones y permisos;
- reservar CIDRs;
- definir ownership de Private DNS Zones;
- registrar resource providers;
- confirmar si Log Analytics será compartido.

## 2. Connectivity Hub

Este repositorio asume que existe un hub corporativo o que será provisto por la plataforma. Como mínimo deben existir o acordarse:

- VNet hub;
- Azure Firewall o NVA equivalente;
- Bastion si se quiere reutilizar acceso administrativo;
- Private DNS Zones y estrategia de linking;
- Log Analytics compartido si se busca centralización.

## 3. AI Governance Hub

Desplegar desde:

`upstream/ai-hub-gateway-solution-accelerator`

Recomendación inicial:

- empezar con `provision`;
- pasar a `up` cuando se quiera incluir la app de ingestión;
- definir pronto si APIM será `Internal` o `External`.

## 4. Foundry Spoke

Desplegar desde:

`upstream/bicep-ptn-aiml-landing-zone`

Recomendación inicial:

- usar `deploymentMode=ailz-integrated`;
- habilitar `networkIsolation=true`;
- reutilizar Bastion y Log Analytics si ya existen;
- crear peering spoke → hub desde la plantilla;
- completar peering hub → spoke desde el lado de plataforma.

## 5. Integración entre hub y spoke

Confirmar:

- resolución DNS privada;
- reachability entre subredes necesarias;
- rutas hacia el firewall del hub;
- acceso del spoke al AI Gateway;
- acceso del hub a los endpoints privados requeridos.

## 6. Validación final

Validaciones mínimas:

- despliegues ARM/Bicep sin error;
- private endpoints creados;
- peering en estado `Connected`;
- APIM accesible según el modo elegido;
- recursos de Foundry accesibles solo por red privada si así se definió.
