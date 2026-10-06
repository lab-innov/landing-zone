import argparse
import json
import re
import uuid
from pathlib import Path


def require(condition, message):
    if not condition:
        raise ValueError(message)


def guid(value):
    return str(uuid.UUID(value)) == value.lower() and uuid.UUID(value).int != 0


def validate(parameters):
    p = {key: item['value'] for key, item in parameters['parameters'].items()}
    serialized = json.dumps(p).lower()
    require(not any(marker in serialized for marker in (
        'pendiente', '00000000-0000-0000-0000-000000000000', 'example.invalid'
    )), 'Sustituya todos los valores de ejemplo antes de continuar.')
    if 'initiatives' in p:
        require(guid(p['tenantId']), 'Tenant inválido.')
        require(bool(p['audience'].strip()) and bool(p['requiredRole'].strip()), 'Falta audiencia o rol.')
        require(len(p['initiatives']) > 0, 'Se requiere al menos una iniciativa.')
        names = set()
        for item in p['initiatives']:
            name = item['name']
            require(re.fullmatch(r'[a-z][a-z0-9-]{0,39}', name), 'Nombre de iniciativa inválido.')
            require(name not in names, 'Las iniciativas deben tener nombres únicos.')
            names.add(name)
            require(item['clientApplicationIds'] and all(guid(x) for x in item['clientApplicationIds']), 'Client IDs inválidos.')
            require(re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9-]{1,62}', item['accountName']), 'Cuenta OpenAI inválida.')
            require(re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_.-]{0,63}', item['deploymentName']), 'Despliegue de modelo inválido.')
            require(re.fullmatch(r'\d{4}-\d{2}-\d{2}(-preview)?', item['apiVersion']), 'Versión de API inválida.')
            for key in ('requestsPerMinute', 'tokensPerMinute', 'monthlyTokenQuota'):
                require(type(item[key]) is int and item[key] > 0, 'Los límites deben ser enteros positivos.')
    elif 'stage' in p:
        require(p['stage'] in ('inicial', 'privada'), 'Etapa inválida.')
        subnet_pattern = r'/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+/subnets/[^/]+'
        for key in ('integrationSubnetId', 'privateEndpointSubnetId'):
            require(re.fullmatch(subnet_pattern, p[key], re.IGNORECASE), 'ID de subred inválido.')
        require(p['integrationSubnetId'].lower() != p['privateEndpointSubnetId'].lower(), 'Las subredes deben ser distintas.')
        require(re.fullmatch(r'/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.OperationalInsights/workspaces/[^/]+', p['logAnalyticsWorkspaceId'], re.IGNORECASE), 'ID de Log Analytics inválido.')
        require('@' in p['publisherEmail'], 'Correo de responsable inválido.')
    else:
        require(guid(p['apimPrincipalId']), 'Object ID de APIM inválido.')
    return p


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Revisa parámetros compilados del gateway antes de enviarlos a Azure.')
    parser.add_argument('parameters', type=Path)
    args = parser.parse_args()
    validate(json.loads(args.parameters.read_text()))
    print('Parámetros revisados. Aún se requieren validate, what-if y pruebas en Azure.')
