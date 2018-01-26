#For when you can't delete corrupted experiment in web service
$ConfigPath = "C:\Users\jeffrey.rowland\Source\Repos\Microsoft Retail Store Customer Insights through NLP\AzureMLUtilities\AzureMLUtilities\AzureMLPS\Default.Config.json"
$AzureMLPSPath = "C:\Users\jeffrey.rowland\Source\Repos\Microsoft Retail Store Customer Insights through NLP\AzureMLUtilities\AzureMLUtilities\AzureMLPS\AzureMLPS.dll"
Unblock-File $AzureMLPSPath
Import-Module $AzureMLPSPath

$exp = Get-AmlExperiment -ConfigFile $ConfigPath | where Description -EQ 'Theme Detection Training'
Remove-AmlExperiment -ConfigFile $ConfigPath -ExperimentId $exp.ExperimentId