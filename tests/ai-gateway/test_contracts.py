import copy
import importlib.util
import json
import os
import subprocess
import tempfile
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / f'{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


checker = load('check-ai-gateway')
preflight = load('preflight-ai-gateway')


class GatewayContracts(unittest.TestCase):
    def setUp(self):
        self.values = {
            'tenantId': '12345678-1234-1234-1234-123456789abc',
            'audience': 'api://gateway', 'requiredRole': 'AiGateway.Invoke',
            'initiatives': [{
                'name': 'piloto', 'clientApplicationIds': ['12345678-1234-1234-1234-123456789abc'],
                'accountName': 'openai-piloto', 'deploymentName': 'chat', 'apiVersion': '2024-10-21',
                'requestsPerMinute': 60, 'tokensPerMinute': 10000, 'monthlyTokenQuota': 1000000,
            }],
        }

    def validate(self):
        return checker.validate({'parameters': {k: {'value': v} for k, v in self.values.items()}})

    def test_valid_configuration(self):
        self.validate()

    def test_empty_callers_rejected(self):
        self.values['initiatives'][0]['clientApplicationIds'] = []
        with self.assertRaises(ValueError): self.validate()

    def test_duplicate_routes_rejected(self):
        self.values['initiatives'].append(copy.deepcopy(self.values['initiatives'][0]))
        with self.assertRaises(ValueError): self.validate()

    def test_negative_limit_rejected(self):
        self.values['initiatives'][0]['tokensPerMinute'] = -1
        with self.assertRaises(ValueError): self.validate()

    def test_path_injection_rejected(self):
        self.values['initiatives'][0]['deploymentName'] = '../../other'
        with self.assertRaises(ValueError): self.validate()

    def test_example_rejected(self):
        self.values['tenantId'] = '00000000-0000-0000-0000-000000000000'
        with self.assertRaises(ValueError): self.validate()

    def test_public_apim_rejected(self):
        with self.assertRaises(ValueError):
            preflight.check_service({'properties': {'publicNetworkAccess': 'Enabled', 'virtualNetworkType': 'External'}})

    def test_private_ingress_without_egress_rejected(self):
        with self.assertRaises(ValueError):
            preflight.check_service({
                'properties': {'publicNetworkAccess': 'Disabled', 'virtualNetworkType': 'None', 'provisioningState': 'Succeeded'},
                'identity': {'type': 'SystemAssigned'}, 'sku': {'name': 'StandardV2'},
            })

    def test_authentication_precedes_routing(self):
        tree = ET.parse(ROOT / 'infra/ai-gateway/policies/chat.xml')
        inbound = tree.getroot().find('inbound')
        tags = [element.tag for element in inbound]
        self.assertLess(tags.index('validate-azure-ad-token'), tags.index('set-backend-service'))
        self.assertEqual(inbound.find('rewrite-uri').get('copy-unmatched-params'), 'false')
        self.assertEqual(inbound.find('authentication-managed-identity').get('ignore-error'), 'false')
        self.assertIsNotNone(inbound.find('validate-azure-ad-token/required-claims/claim'))
        self.assertIsNone(tree.getroot().find('.//retry'))

    def test_compiled_template_security(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'foundation.json'
            compiler = os.environ.get('BICEP_BIN', 'bicep')
            subprocess.run([compiler, 'build', str(ROOT / 'infra/ai-gateway/foundation.bicep'), '--outfile', str(output)], check=True)
            foundation = json.loads(output.read_text())
        self.assertEqual(foundation['parameters']['stage']['defaultValue'], 'privada')
        resources = foundation['resources']
        if isinstance(resources, dict): resources = resources.values()
        resources = list(resources)
        self.assertFalse(any(r['type'] == 'Microsoft.Network/privateDnsZones' for r in resources))
        service = next(r for r in resources if r['type'] == 'Microsoft.ApiManagement/service')
        self.assertEqual(service['sku']['name'], 'StandardV2')
        self.assertEqual(service['identity']['type'], 'SystemAssigned')


if __name__ == '__main__':
    unittest.main()
