import argparse
import importlib.util
import json
import subprocess
from pathlib import Path

spec = importlib.util.spec_from_file_location('parameters', Path(__file__).with_name('check-ai-gateway.py'))
parameters = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parameters)


def read_azure(*args):
    result = subprocess.run(['az', *args, '--output', 'json', '--only-show-errors'], check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def check_service(service):
    props = service['properties']
    private = props.get('publicNetworkAccess') == 'Disabled' or props.get('virtualNetworkType') == 'Internal'
    parameters.require(private, 'APIM debe tener ingreso privado antes de configurar las APIs.')
    parameters.require('SystemAssigned' in service.get('identity', {}).get('type', ''), 'APIM requiere identidad administrada de sistema.')
    parameters.require(service.get('sku', {}).get('name') in ('StandardV2', 'PremiumV2', 'Developer', 'Premium', 'Standard', 'Basic'), 'Nivel APIM fuera de la base revisada.')
    parameters.require(props.get('virtualNetworkType') in ('Internal', 'External'), 'Falta conexión de salida hacia los modelos privados.')
    parameters.require(props.get('provisioningState') == 'Succeeded', 'APIM todavía no terminó de aprovisionarse.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Consulta Azure sin modificar recursos antes de configurar el gateway.')
    parser.add_argument('parameters', type=Path)
    parser.add_argument('--subscription', required=True)
    parser.add_argument('--resource-group', required=True)
    args = parser.parse_args()
    p = parameters.validate(json.loads(args.parameters.read_text()))
    account = read_azure('account', 'show', '--subscription', args.subscription)
    if 'tenantId' in p:
        parameters.require(account['tenantId'].lower() == p['tenantId'].lower(), 'La suscripción no pertenece al tenant configurado.')
    if 'apimName' in p:
        services = read_azure('resource', 'list', '--subscription', args.subscription, '--resource-group', args.resource_group, '--resource-type', 'Microsoft.ApiManagement/service')
        matches = [s for s in services if s['name'].lower() == p['apimName'].lower()]
        if p.get('stage') == 'inicial':
            parameters.require(not matches, 'La etapa inicial solo se permite para una instancia nueva; no reabrir una existente.')
        else:
            parameters.require(len(matches) == 1, 'No se encontró la instancia APIM esperada.')
            service = read_azure('resource', 'show', '--ids', matches[0]['id'], '--api-version', '2024-05-01')
            if 'initiatives' in p:
                check_service(service)
            else:
                connections = service['properties'].get('privateEndpointConnections', [])
                parameters.require(any(c.get('properties', {}).get('privateLinkServiceConnectionState', {}).get('status') == 'Approved' for c in connections), 'Falta un endpoint privado aprobado para cerrar la entrada pública.')
    print('Preflight de Azure correcto. Verificar DNS, rutas y políticas heredadas antes del despliegue.')
