@description('Location of the resources')
param location string = resourceGroup().location

@description('Password for the SQL Server admin user. PLEASE CHANGE THIS BEFORE DEPLOYMENT!')
param sqlAdminPassword string = 'n8&tJA@RZ2qVB!vX'

@description('Deployments for OpenAI')
param deployments array = [
  {
    name: 'gpt-4o'
    capacity: 40
    version: '2024-05-13'
  }
  {
    name: 'text-embedding-ada-002'
    capacity: 120
    version: '2'
  }
]

@description('Restore the service instead of creating a new instance. This is useful if you previously soft-delted the service and want to restore it. If you are restoring a service, set this to true. Otherwise, leave this as false.')
param restore bool = false

var cosmosDbName = '${uniqueString(resourceGroup().id)}-cosmosdb'
var cosmosDbDatabaseName = 'ContosoSuites'
var storageAccountName = '${uniqueString(resourceGroup().id)}sa'
var searchServiceName = '${uniqueString(resourceGroup().id)}-search'
var openAIName = '${uniqueString(resourceGroup().id)}2-openai'
var speechServiceName = '${uniqueString(resourceGroup().id)}2-speech'
var languageServiceName = '${uniqueString(resourceGroup().id)}-lang'
var webAppNameApi = '${uniqueString(resourceGroup().id)}-api'
var webAppNameDash = '${uniqueString(resourceGroup().id)}-dash'
var appServicePlanName = '${uniqueString(resourceGroup().id)}-cosu-asp'
var logAnalyticsName = '${uniqueString(resourceGroup().id)}-cosu-la'
var appInsightsName = '${uniqueString(resourceGroup().id)}-cosu-ai'
var webAppSku = 'S1'
var registryName = '${uniqueString(resourceGroup().id)}cosureg'
var registrySku = 'Standard'
var sqlServerName = '${uniqueString(resourceGroup().id)}-sqlserver'
var sqlDatabaseName = 'ContosoSuitesBookings'
var sqlAdminUsername = 'contosoadmin'

var locations = [
  {
    locationName: location
    failoverPriority: 0
    isZoneRedundant: false
  }
]

@description('Creates an Azure Cosmos DB NoSQL account.')
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosDbName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    databaseAccountOfferType: 'Standard'
    locations: locations
  }
}

@description('Creates an Azure Cosmos DB NoSQL API database.')
resource cosmosDbDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmosDbAccount
  name: cosmosDbDatabaseName
  properties: {
    resource: {
      id: cosmosDbDatabaseName
    }
  }
}

@description('Creates an Azure SQL Server.')
resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
  }
}

@description('Creates an Azure SQL Database.')
resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
  sku: {
    name: 'S2'
    tier: 'Standard'
    capacity: 50
  }
}

@description('Creates an Azure Storage account.')
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

@description('Creates an Azure AI Search service.')
resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: searchServiceName
  location: location
  sku: {
    name: 'standard'
  }
}

@description('Creates an Azure OpenAI resource.')
resource openAI 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: openAIName
  location: location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
    tier: 'Standard'
  }
  properties: {
    customSubDomainName: openAIName
    publicNetworkAccess: 'Enabled'
    restore: restore
  }
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for deployment in deployments: {
  parent: openAI
  name: deployment.name
  sku: {
    name: 'Standard'
    capacity: deployment.capacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: deployment.name
      version: deployment.version
    }
  }
}]

@description('Creates an Azure AI Services Speech service.')
resource speechService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: speechServiceName
  location: location
  kind: 'SpeechServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: speechServiceName
    publicNetworkAccess: 'Enabled'
    restore: restore
  }
}

@description('Creates an Azure AI Services Language service.')
resource languagteService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: languageServiceName
  location: location
  kind: 'TextAnalytics'
  sku: {
    name: 'F0'
  }
  properties: {
    customSubDomainName: languageServiceName
    publicNetworkAccess: 'Enabled'
    restore: restore
  }
}

@description('Creates an Azure Log Analytics workspace.')
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    workspaceCapping: {
      dailyQuotaGb: 1
    }
  }
}

@description('Creates an Azure Application Insights resource.')
resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

@description('Creates an Azure Container Registry.')
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-12-01' = {
  name: registryName
  location: location
  sku: {
    name: registrySku
  }
  properties: {
    adminUserEnabled: true
  }
}

@description('Creates an Azure App Service Plan.')
resource appServicePlan 'Microsoft.Web/serverFarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  properties: {
    reserved: true
  }
  sku: {
    name: webAppSku
  }
}

@description('Creates an Azure App Service for the API.')
resource appServiceApp 'Microsoft.Web/sites@2022-09-01' = {
  name: webAppNameApi
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerRegistry.name}.azurecr.io/${uniqueString(resourceGroup().id)}/techexcel/csapi'
      http20Enabled: true
      minTlsVersion: '1.2'
      appCommandLine: ''
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${containerRegistry.name}.azurecr.io'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: containerRegistry.name
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        ]
      }
    }
}

@description('Creates an Azure App Service for the Dashboard.')
resource appServiceAppDash 'Microsoft.Web/sites@2022-09-01' = {
  name: webAppNameDash
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerRegistry.name}.azurecr.io/${uniqueString(resourceGroup().id)}/techexcel/csdash'
      http20Enabled: true
      minTlsVersion: '1.2'
      appCommandLine: ''
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${containerRegistry.name}.azurecr.io'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: containerRegistry.name
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        ]
      }
    }
}

output cosmosDbEndpoint string = cosmosDbAccount.properties.documentEndpoint
output storageAccountName string = storageAccount.name
output searchServiceName string = searchService.name
output openAIEndpoint string = openAI.properties.endpoint
output speechServiceName string = speechService.name
output application_name string = appServiceApp.name
output application_url string = appServiceApp.properties.hostNames[0]
output container_registry_name string = containerRegistry.name
output application_name_dash string = appServiceAppDash.name
output application_url_dash string = appServiceAppDash.properties.hostNames[0]
