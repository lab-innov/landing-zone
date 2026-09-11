// Contratos evaluados por ARM también cuando se omite el script local.
@allowed([true])
param validNetwork bool
@allowed([true])
param validRuntime bool
@allowed([true])
param validApps bool
@allowed([true])
param validGateway bool

@allowed([true])
param validEnvironment bool

output valid bool = validEnvironment && validNetwork && validRuntime && validApps && validGateway
