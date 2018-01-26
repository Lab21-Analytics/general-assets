#
# BackupExperimentGraphs.ps1
#
# Pulls experiments from AML workspace and saves them to local Git repo as json
# Json files must still be commited to repo and pushed by user

param(
	[string]$ConfigFile = 'DevAMLPS.Config.json',
	[string]$BackupDir = (Join-Path $PSScriptRoot "..\..\AzureMLExperiments\GraphBackups")
)

Write-Debug (resolve-path $ConfigFile) -Debug
$ConfigFile = resolve-path $ConfigFile

Write-Debug (resolve-path $BackupDir) -Debug
$BackupDir = resolve-path $BackupDir

if(!(Test-Path $BackupDir))
{
	Throw "Could not find graph backup directory"
}

$AzureMLPSPath = join-path $PSScriptRoot "AzureMLPS\AzureMLPS.dll"
$ConfigPath = $ConfigFile
Unblock-File $AzureMLPSPath
Import-Module $AzureMLPSPath

$workspace = Get-AmlWorkspace -ConfigFile $ConfigPath
$exps = Get-AmlExperiment -ConfigFile $ConfigPath

# For each experiment where category is "user" export graph as json to backups
# Assuming category = "user" means it is user created
$exps | Where-Object {$_.Category -eq "user"} |ForEach-Object {
	$filePath = Join-Path $backupDir ($_.Description + ".json")
	echo (Export-AmlExperimentGraph -ConfigFile $ConfigPath -ExperimentId $_.ExperimentId -OutputFile $filePath)
}