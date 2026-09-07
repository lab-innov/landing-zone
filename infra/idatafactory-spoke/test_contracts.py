"""Pruebas de conectividad declarativa y detección de IPAM inválido."""
import copy
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from check_parameters import validate

ROOT = Path(__file__).resolve().parent

class Contracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        target = Path(cls.temp.name) / 'main.json'
        bicep = os.environ.get('BICEP_BIN', str(Path.home()/'.azure/bin/bicep'))
        env = dict(os.environ, DOTNET_BUNDLE_EXTRACT_BASE_DIR=cls.temp.name)
        subprocess.run([bicep, 'build', str(ROOT/'main.bicep'), '--outfile', str(target)], env=env, check=True)
        cls.template = json.loads(target.read_text())
        cls.modules = {x['name']:x['properties']['template'] for x in cls.template['resources']
                       if x['type']=='Microsoft.Resources/deployments'}

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def resources(self, suffix):
        return next(v['resources'] for k,v in self.modules.items() if suffix in k)

    def test_private_ingress_and_function_egress(self):
        app = next(x for x in self.resources('-app-') if x['type']=='Microsoft.Web/sites')
        p = app['properties']
        self.assertEqual(p['publicNetworkAccess'], 'Disabled')
        self.assertFalse(p['enabled'])
        self.assertTrue(p['vnetImagePullEnabled'])
        self.assertTrue(p['vnetContentShareEnabled'])
        self.assertTrue(p['siteConfig']['vnetRouteAllEnabled'])
        self.assertIn('subnetId', p['virtualNetworkSubnetId'])

    def test_dns_ownership_and_no_historical_jobs(self):
        raw=json.dumps(self.template)
        for forbidden in ['Microsoft.Network/privateDnsZones','Microsoft.Network/privateEndpoints/privateDnsZoneGroups',
                          'Microsoft.Automation/automationAccounts/jobs','Microsoft.Web/sites/functions',
                          'Microsoft.EventGrid/systemTopics/eventSubscriptions']:
            self.assertNotIn(forbidden, raw)

    def test_databricks_no_public_ip(self):
        dbx = next(x for x in self.resources('-databricks') if x['type']=='Microsoft.Databricks/workspaces')
        self.assertTrue(dbx['properties']['parameters']['enableNoPublicIp']['value'])
        self.assertEqual(dbx['properties']['requiredNsgRules'], 'NoAzureDatabricksRules')
        self.assertEqual(dbx['properties']['publicNetworkAccess'], 'Disabled')

    def test_storage_and_registry_private(self):
        storage = next(x for x in self.resources('-storage-') if x['type']=='Microsoft.Storage/storageAccounts')
        self.assertEqual(storage['properties']['publicNetworkAccess'],'Disabled')
        self.assertEqual(storage['properties']['networkAcls']['bypass'],'None')
        acr = next(x for x in self.resources('-services') if x['type']=='Microsoft.ContainerRegistry/registries')
        self.assertEqual(acr['sku']['name'],'Premium')
        self.assertFalse(acr['properties']['adminUserEnabled'])

    def test_targets_and_dedicated_subnets(self):
        targets = self.template['variables']['baseTargets']
        groups = [x['groupId'] for x in targets]
        self.assertEqual(groups.count('sites'),6)
        self.assertEqual(groups.count('blob'),11)
        self.assertEqual(groups.count('dfs'),1)
        self.assertEqual(groups.count('Sql'),3)
        definitions=next(v['variables']['definitions'] for k,v in self.modules.items() if '-network' in k)
        self.assertEqual(sum(x['delegation']=='Microsoft.Web/serverFarms' for x in definitions),5)
        self.assertEqual(sum(x['delegation']=='Microsoft.Databricks/workspaces' for x in definitions),2)

    def test_parameter_rejections(self):
        example=json.loads((ROOT/'main.parameters.example.json').read_text())
        platform=json.loads((ROOT/'platform.example.json').read_text())
        self.assertTrue(validate(example,platform))
        p={k:v['value'] for k,v in example['parameters'].items()}
        p.update(prefix='idf-test',addressPrefix='10.80.0.0/21',dnsServers=['10.0.0.4'],firewallIp='10.0.0.5',
                 hubVnetId='/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/hub/providers/Microsoft.Network/virtualNetworks/hub',
                 logAnalyticsWorkspaceResourceId='/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/hub/providers/Microsoft.OperationalInsights/workspaces/logs',
                 commonsImage='commons-func@sha256:'+'a'*64)
        p['subnetPrefixes']={k:f'10.80.{i}.0/24' for i,k in enumerate(p['subnetPrefixes'])}
        platform.update({k:True for k in platform if k!='connectedPrefixes'})
        platform['connectedPrefixes']=['10.0.0.0/16']
        document={'parameters':{k:{'value':v} for k,v in p.items()}}
        self.assertEqual(validate(document,platform),[])
        for field,value in [('addressPrefix','8.8.0.0/16'),('dnsServers',[]),('commonsImage','commons:latest')]:
            bad=copy.deepcopy(document);bad['parameters'][field]['value']=value
            self.assertTrue(validate(bad,platform),field)
        bad=copy.deepcopy(document);bad['parameters']['subnetPrefixes']['value']['web']='10.80.0.0/24'
        self.assertTrue(validate(bad,platform))
        bad=copy.deepcopy(platform);bad['connectedPrefixes'].append('10.80.0.0/16')
        self.assertTrue(validate(document,bad))
        bad=copy.deepcopy(platform);bad['centralDnsDineReady']=False
        self.assertTrue(validate(document,bad))

if __name__=='__main__':
    unittest.main()
