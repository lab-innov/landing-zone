#!/usr/bin/env python3
"""Comprobación local de parámetros y requisitos declarados de CAF; no consulta Azure."""
import ipaddress
import json
import re
import sys
from pathlib import Path

RFC1918 = [ipaddress.ip_network(x) for x in ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')]
SUBNETS = {'pe': 24, 'web': 26, 'audits': 26, 'commons': 26, 'notifications': 26,
           'processing': 26, 'dbxhost': 26, 'dbxcontainer': 26}

def validate(document, platform):
    errors = []
    p = {k: v.get('value') for k, v in document.get('parameters', {}).items()}
    if 'REEMPLAZAR' in json.dumps([document, platform]):
        return ['Sustituir todos los marcadores REEMPLAZAR.']
    def network(value):
        n = ipaddress.ip_network(value, strict=True)
        if n.version != 4 or not any(n.subnet_of(r) for r in RFC1918):
            raise ValueError('Se requiere IPv4 RFC1918.')
        return n
    try:
        if not re.fullmatch(r'[a-z][a-z0-9-]{1,14}[a-z0-9]', p['prefix']):
            errors.append('Prefijo: 3–16 caracteres, minúsculas, números y guiones.')
        vnet = network(p['addressPrefix'])
        prefixes = p['subnetPrefixes']
        if set(prefixes) != set(SUBNETS):
            errors.append('Se requieren exactamente las ocho subredes documentadas.')
        subnets = []
        for name, max_prefix in SUBNETS.items():
            n = network(prefixes[name])
            if not n.subnet_of(vnet) or n.prefixlen > max_prefix:
                errors.append(f'Subred {name}: debe pertenecer a la VNet y ser /{max_prefix} o mayor.')
            if any(n.overlaps(previous) for previous in subnets):
                errors.append(f'Subred {name}: solapamiento interno.')
            subnets.append(n)
        connected = [network(x) for x in platform['connectedPrefixes']]
        if not connected:
            errors.append('Faltan los CIDR del hub y de las redes conectadas.')
        if any(vnet.overlaps(n) for n in connected):
            errors.append('El spoke se solapa con redes conectadas.')
        for value in [p['firewallIp'], *p['dnsServers']]:
            ip = ipaddress.ip_address(value)
            if ip.version != 4 or not any(ip in n for n in connected):
                errors.append('Firewall y DNS deben pertenecer a las redes conectadas declaradas.')
        if not p['dnsServers']:
            errors.append('Falta DNS corporativo.')
        for field, provider, resource in [('hubVnetId','Microsoft.Network','virtualNetworks'),
                                          ('logAnalyticsWorkspaceResourceId','Microsoft.OperationalInsights','workspaces')]:
            if not re.fullmatch(fr'/subscriptions/[0-9a-fA-F-]{{36}}/resourceGroups/[^/]+/providers/{provider}/{resource}/[^/]+',p[field],re.I):
                errors.append(f'ID de recurso inválido: {field}.')
        for field in ('ipamApproved','centralDnsDineReady','hubReturnPeeringReady','firewallEgressReady'):
            if platform.get(field) is not True:
                errors.append(f'Requisito CAF pendiente: {field}.')
        browser_field = ('newDatabricksBrowserAuthApproved' if p.get('createDatabricksBrowserAuth', False)
                         else 'sharedDatabricksBrowserAuthReady')
        if platform.get(browser_field) is not True:
            errors.append(f'Falta confirmar {browser_field}.')
        if p.get('useRemoteGateways',False) and platform.get('gatewayTransitReady') is not True:
            errors.append('Falta gateway transit en el hub.')
        if not re.fullmatch(r'[a-z0-9][a-z0-9._/-]*@sha256:[0-9a-f]{64}',p['commonsImage']):
            errors.append('commonsImage requiere repositorio@sha256:digest inmutable, sin hostname de ACR.')
    except (KeyError, ValueError, TypeError) as exc:
        errors.append(f'Parámetro ausente o inválido: {exc}')
    return errors

if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit('Uso: python3 check_parameters.py parametros.json plataforma.json')
    errors = validate(json.loads(Path(sys.argv[1]).read_text()), json.loads(Path(sys.argv[2]).read_text()))
    print('\n'.join(errors) if errors else 'Parámetros locales válidos; falta verificación real en Azure.')
    sys.exit(bool(errors))
