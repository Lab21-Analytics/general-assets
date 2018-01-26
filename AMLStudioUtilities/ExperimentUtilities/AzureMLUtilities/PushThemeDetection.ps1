#
# PushThemeDetection.ps1
#

param(
	[string]$ConfigFile = 'DevAMLPS.Config.json'
)

$Experiments =  "C:\Users\jeffrey.rowland\Source\Repos\Microsoft Retail Store Customer Insights through NLP\AzureMLExperiments\GraphBackups\Theme Detection Scoring.json",
				"C:\Users\jeffrey.rowland\Source\Repos\Microsoft Retail Store Customer Insights through NLP\AzureMLExperiments\GraphBackups\Theme Detection Training.json",
				"C:\Users\jeffrey.rowland\Source\Repos\Microsoft Retail Store Customer Insights through NLP\AzureMLExperiments\GraphBackups\Theme Clustering.json"


$Jobs = $Experiments | ForEach-Object {
	Start-Job -ArgumentList $_,$ConfigFile,$PSScriptRoot -FilePath (Join-Path $PSScriptRoot 'PushExperimentGraph.ps1') 
}
