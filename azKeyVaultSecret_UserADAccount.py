import adal, getpass
from msrestazure.azure_active_directory import UserPassCredentials
from azure.keyvault import KeyVaultClient, KeyVaultAuthentication

#region Key Vault Parameters
#--------------------------------------------------------
# Setup Azure Key Vault Authentication Parameters
#--------------------------------------------------------
VAULT_URI = 'https://<KeyVaultName>.vault.azure.net/'   #Replace with Azure Key Vault URI, Should be input argument
userName = 'username@azureaddomain.com'                 #Replace with Azure AD User Name, Prompt or input argument
#--------------------------------------------------------
#endregion

#region Key Vault Connection
#--------------------------------------------------------
# Connection to Azure Key Vault
#--------------------------------------------------------
userCredential = UserPassCredentials(userName, getpass.getpass(prompt = 'Azure AD Password: '))
kvClient = KeyVaultClient(userCredential)
#---------------------------------------------------------
#endregion

#region Get Key Vault Secret
#---------------------------------------------------------
# Retrieve Key Vault Secrets
#---------------------------------------------------------
keyValue = (kvClient.get_secret(VAULT_URI,'<Key_Name>','')).value  #Replace with correct Key Vault Secret Key Name, Should be input argument
#---------------------------------------------------------
#endregion


