#!/usr/bin/env python3
"""Comprueba parámetros locales antes de validar el despliegue en Azure."""
import ipaddress
import json
import re
import sys
from pathlib import Path


def check(p):
    errors = []
    def require(condition, message):
        if not condition:
            errors.append(message)
    def network(value):
        return ipaddress.IPv4Network(value, strict=True)
    rfc1918 = [network(x) for x in ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')]
    require('REEMPLAZAR' not in json.dumps(p), 'Sustituir todos los marcadores REEMPLAZAR.')
    require(bool(re.fullmatch(r'[a-z0-9-]{2,12}', p.get('workload', ''))), 'workload: 2–12 caracteres a-z, 0-9 o guion.')
    prefixes = p.get('prefixes', {})
    nets = {}
    for key in ('vnet', 'foundry', 'containers', 'appGateway', 'privateEndpoints', 'gateway', 'firewall'):
        try:
            nets[key] = network(prefixes[key])
            require(any(nets[key].subnet_of(block) for block in rfc1918), f'{key}: debe pertenecer a RFC1918.')
        except (ValueError, KeyError):
            errors.append(f'{key}: CIDR IPv4 válido y alineado requerido.')
    reserved = [network(x) for x in ('172.30.0.0/16', '172.31.0.0/16')]
    if 'vnet' in nets:
        require(not any(nets['vnet'].overlaps(x) for x in reserved), 'VNet se solapa con rangos reservados por ACA.')
    subnets = [(k, v) for k, v in nets.items() if k != 'vnet']
    for i, (name, net) in enumerate(subnets):
        require('vnet' in nets and net.subnet_of(nets['vnet']), f'{name}: debe estar dentro de la VNet.')
        for other, othernet in subnets[i+1:]:
            require(not net.overlaps(othernet), f'Solapamiento: {name} / {other}.')
    for name, maximum in [('foundry', 27), ('containers', 27), ('appGateway', 24), ('privateEndpoints', 26), ('gateway', 27), ('firewall', 26)]:
        if name in nets:
            require(nets[name].prefixlen <= maximum, f'{name}: usar /{maximum} o mayor para este patrón.')
    for label, addresses in [('dnsServers', p.get('dnsServers', [])), ('hubFirewallIp', [p.get('hubFirewallIp', '')])]:
        require(bool(addresses), f'{label}: requerido.')
        for address in addresses:
            try:
                ip = ipaddress.IPv4Address(address)
                require(any(ip in n for n in rfc1918), f'{label}: requiere IP privada RFC1918.')
            except ValueError:
                errors.append(f'{label}: IP inválida.')
    require(bool(re.fullmatch(r'/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+', p.get('hubVnetId', ''))), 'hubVnetId: ID completo requerido.')
    require(bool(p.get('cafClientPrefixes')), 'cafClientPrefixes: especificar redes de clientes.')
    for value in p.get('cafClientPrefixes', []):
        try:
            net = network(value)
            require(any(net.subnet_of(x) for x in rfc1918), 'Clientes: usar redes privadas CAF.')
        except ValueError:
            errors.append('Clientes: CIDR inválido.')
    mode = p.get('privateDnsMode', 'policy')
    require(mode in ('policy', 'existing'), 'privateDnsMode inválido.')
    if mode == 'existing':
        zones = p.get('privateDnsZoneIds', {})
        for key in ('foundry', 'blob', 'agentBlob', 'vault', 'acr', 'cosmos', 'search'):
            ids = zones.get(key, [])
            require(len(ids) == (3 if key == 'foundry' else 1), f'DNS {key}: IDs de zonas incompletos.')
            require(all('/providers/Microsoft.Network/privateDnsZones/' in x for x in ids), f'DNS {key}: ID inválido.')
    if p.get('deployApplications'):
        require(p.get('activateAgentRuntime'), 'Activar runtime Foundry antes de las aplicaciones.')
        for key in ('frontendImage', 'backendImage'):
            require(bool(re.fullmatch(r'[a-z0-9]+\.azurecr\.io/[^\s]+(?::[^\s]+|@sha256:[a-f0-9]{64})', p.get(key, ''))), f'{key}: imagen de ACR con etiqueta o digest requerida.')
    if p.get('deployGateway'):
        require(p.get('deployApplications'), 'Gateway requiere ambas aplicaciones.')
        require(bool(re.fullmatch(r'[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', p.get('gatewayHostname', ''))), 'Hostname TLS requerido.')
        try:
            ip = ipaddress.IPv4Address(p.get('gatewayPrivateIp', ''))
            net = nets['appGateway']
            require(ip in net and int(ip)-int(net.network_address) >= 4 and ip != net.broadcast_address, 'IP del gateway fuera de subred o reservada por Azure.')
        except (ValueError, KeyError):
            errors.append('IP privada del gateway inválida.')
    return errors


if __name__ == '__main__':
    document = json.loads(Path(sys.argv[1]).read_text())
    errors = check({k: v['value'] for k, v in document['parameters'].items()})
    if errors:
        print('\n'.join(f'- {error}' for error in errors))
        sys.exit(1)
    print('Parámetros locales válidos. Pendientes IPAM, DNS, RBAC, capacidad, políticas y validación Azure.')
