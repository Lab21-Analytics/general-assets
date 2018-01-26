#
# uploadExperimentGraphs.ps1
#
# Pushes graphs from backup to AML workspace

param(
	[string]$GraphFile,
	[string]$ConfigFile = 'config.json',
	[string]$ScriptRoot = $PSScriptRoot,
	[string]$NewName
)

if(!(Test-Path $GraphFile))
{
	Throw "Could not find graph file $GraphFile"
}

Write-Output "hello world"

$AzureMLPSPath = join-path $ScriptRoot "AzureMLPS\AzureMLPS.dll"
Unblock-File $AzureMLPSPath
Import-Module $AzureMLPSPath
# Config Path is for extracting config info
# Config File is for AMLPS Comandlets, they require a relative path to work 
$ConfigPath = join-path(join-path $ScriptRoot "AzureMLPS") $ConfigFile
$Config = ConvertFrom-Json -InputObject (Gc $ConfigPath -Raw)



$ExperimentGraph = ConvertFrom-Json -InputObject (Gc $GraphFile -Raw)

$ExperimentGraph.Graph.ModuleNodes | where Comment -Like 'Custom Module: *' | ForEach-Object {
		$ModuleName = $_.Comment -split ": " | select -Index 1
		$Module = get-AMLModule -ConfigFile $ConfigFile -Custom | where Name -eq $ModuleName
		if(!$Module) {
			Write-Error "Could not find module '$ModuleName' in destination workspace"
			# Will fail if custom module directory has zip files
			& (join-path $ScriptRoot "BuildDeployModules.ps1") -ConfigFile $ConfigFile 
		}
		$ModuleNode = $ExperimentGraph.Graph.ModuleNodes | Where-Object {($_.Comment -split ": " | select -Index 1) -eq $ModuleName}
		if(!$ModuleNode) {Write-Warning "Skipping $ModuleName, it does not exist in experiment graph"}
		$ModuleNode | ForEach-Object{
			$_.ModuleId = $Module.Id
		}
}


$ExperimentGraph.ParentExperimentId = $null
#$ExperimentGraph.RunId = $null

$ExperimentGraph.Graph.ModuleNodes | where Comment -Like '*Input' | ForEach-Object {
	if(($_.ModuleParameters | where Name -EQ "Please Specify Data Source").Value -eq "AzureBlobStorage"){
		($_.ModuleParameters | where Name -eq 'Account Name').Value = $Config."Account Name"
		($_.ModuleParameters | where Name -eq 'Account Key').Value = $Config."Account Key"
	} elseif(($_.ModuleParameters | where Name -EQ "Please Specify Data Source").Value -eq "SqlAzure"){
		($_.ModuleParameters | where Name -eq 'Database Server Name').Value = $Config."Database Server Name"
		($_.ModuleParameters | where Name -eq 'Server User account Name').Value = $Config."Server User account Name"
		($_.ModuleParameters | where Name -eq 'Server User Account Password').Value = $Config."Server User Account Password"
	}
}

$DestExperiment = get-AmlExperiment -ConfigFile $ConfigFile | where Description -eq $ExperimentGraph.Description

if(!$DestExperiment){
	if(!$NewName) {
		$NewName = $ExperimentGraph.Description
	}
	Write-Output "Creating new experiment " $NewName
	$TempFile = New-TemporaryFile
	ConvertTo-Json -InputObject $ExperimentGraph -Depth 99 | Out-File $TempFile.FullName
	Import-AmlExperimentGraph -ConfigFile $ConfigFile -InputFile $TempFile.FullName -NewName $NewName
	$NewExperiment = Get-AmlExperiment -ConfigFile $ConfigFile | where Description -EQ $NewName
	Start-AmlExperiment -ConfigFile $ConfigFile -ExperimentId $NewExperiment.ExperimentId
} else {
	Write-Output "Overwriting experiment " $DestExperiment.Description
	$TempFile = New-TemporaryFile
	Export-AmlExperimentGraph -ConfigFile $ConfigFile -ExperimentId $DestExperiment.ExperimentId -OutputFile $TempFile.FullName
	$DestExperimentGraph = ConvertFrom-Json -InputObject (Gc $TempFile.FullName -Raw)
	$DestExperimentGraph.Graph = $ExperimentGraph.Graph
	$DestExperimentGraph.WebService.Inputs = $ExperimentGraph.WebService.Inputs
	$DestExperimentGraph.WebService.Outputs = $ExperimentGraph.WebService.Outputs
	$DestExperimentGraph.WebService.Parameters = $ExperimentGraph.WebService.Parameters

	$TempFile = New-TemporaryFile
	ConvertTo-Json -InputObject $DestExperimentGraph -Depth 99 | Out-File $TempFile.FullName
	if(!$NewName) {
		Import-AMLExperimentGraph -ConfigFile $ConfigFile -InputFile $TempFile.FullName -Overwrite
		Start-AmlExperiment -ConfigFile $ConfigFile -ExperimentId $DestExperiment.ExperimentId
	} else {
		Import-AmlExperimentGraph -ConfigFile $ConfigFile -InputFile $TempFile.FullName -NewName $NewName
		$NewExperiment = Get-AmlExperiment -ConfigFile $ConfigFile | where Description -EQ $NewName
		Start-AmlExperiment -ConfigFile $ConfigFile -ExperimentId $NewExperiment.ExperimentId
	}
}