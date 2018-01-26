#Test Push
$GraphFile = "C:\Users\jeffrey.rowland\Source\Repos\Microsoft Retail Store Customer Insights through NLP\AzureMLExperiments\GraphBackups\DT1.json"
$ConfigPath = "DevAMLPS.Config.json"

if(!(Test-Path $GraphFile))
{
	Throw "Could not find graph file"
}

Write-Output "hello world"

$AzureMLPSPath = join-path $ScriptRoot "AzureMLPS\AzureMLPS.dll"
# Config Path is for extracting config info
# Config File is for AMLPS Comandlets, they require a relative path to work 
$ConfigPath = join-path(join-path $ScriptRoot "AzureMLPS") $ConfigFile
Unblock-File $AzureMLPSPath
Import-Module $AzureMLPSPath

$Config = ConvertFrom-Json -InputObject (Gc $ConfigPath -Raw)

$ExperimentGraph = ConvertFrom-Json -InputObject (Gc $GraphFile -Raw)

Write-Output "Creating new experiment " 
$TempFile = New-TemporaryFile
ConvertTo-Json -InputObject $ExperimentGraph -Depth 99 | Out-File $TempFile.FullName
Import-AmlExperimentGraph -ConfigFile $ConfigPath -InputFile $TempFile.FullName -NewName "test experiment"
$NewExperiment = Get-AmlExperiment -ConfigFile $ConfigPath | where Description -EQ "test experiment"
Start-AmlExperiment -ConfigFile $ConfigPath -ExperimentId $NewExperiment.ExperimentId

8a1dbb274a0c4701b591028123cb117c.f-id.ebe6647c5d744be1b2f05897efa50386
