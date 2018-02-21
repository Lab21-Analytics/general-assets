import adal
from msrestazure.azure_active_directory import ServicePrincipalCredentials, AdalAuthentication
from msrestazure.azure_cloud import AZURE_PUBLIC_CLOUD
from azure.keyvault import KeyVaultClient, KeyVaultAuthentication

#region Service Principal Parameters
#-------------------------------------------------------
# Set up Azure Service Principal Parameters
#-------------------------------------------------------
SUBSCRIPTION_ID = 'aabbccdd-0000-1111-2222-eeeeffffgggg' #Replace with Actual Target Azure Subscription ID, Should be input argument
TENANT_ID = 'aabbccdd-0000-1111-2222-eeeeffffgggg'       #Replace with Actual Azure AD Tenant ID, Should be input argument
CLIENT_ID = 'aabbccdd-0000-1111-2222-eeeeffffgggg'       #Replace with Actual Azure Application ID, Should be input argument
KEY = 'Application_Generated_Secret'                     #Replace with Actual Azure Application KEY Value, Should be input argument
#--------------------------------------------------------
#endregion

#region Key Vault Parameters
#--------------------------------------------------------
# Setup Azure Key Vault Authentication Parameters
#--------------------------------------------------------
LOGIN_ENDPOINT = AZURE_PUBLIC_CLOUD.endpoints.active_directory
RESOURCE_URI = 'https://vault.azure.net'
VAULT_URI = 'https://<KeyVaultName>.vault.azure.net/'   #Replace with Azure Key Vault URI, Should be input argument
#--------------------------------------------------------
#endregion

#region Key Vault Connection
#--------------------------------------------------------
# Connect to Azure Key Vault as a Client
#--------------------------------------------------------
context = adal.AuthenticationContext(LOGIN_ENDPOINT + '/' + TENANT_ID)
credentials = AdalAuthentication(
    context.acquire_token_with_client_credentials,
    RESOURCE_URI,
    CLIENT_ID,
    KEY
)
kvClient = KeyVaultClient(credentials)
#---------------------------------------------------------
#endregion

#region Get Key Vault Secret
#---------------------------------------------------------
# Retrieve Key Vault Secrets
#---------------------------------------------------------
keyValue = (kvClient.get_secret(VAULT_URI,'<Key_Name>','')).value  #Replace with correct Key Vault Secret Key Name, Should be input argument
#---------------------------------------------------------
#endregion

