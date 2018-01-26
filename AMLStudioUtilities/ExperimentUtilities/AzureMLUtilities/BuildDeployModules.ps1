#
# BuildDeployModules.ps1
#
# New-AmlCustomModule seems to have a size limit for zipped directory
# 3170 KB works while 5300 KB does not
# No longer an issue since we are only extending AML with one R package qlcMatrix
# TODO: 
#	* Investigate batching upload
#	* Implement test experiment for validating module changes
#	* Investigate New-AMLWebService to see if it now supports overwritting
param(
	[string]$ConfigFile = 'DevAMLPS.Config.json',
	[string]$Source = (join-path $PSScriptRoot "..\..\AzureMLExperiments\R\ProdModules")
)

$AzureMLPSPath = join-path $PSScriptRoot "AzureMLPS\AzureMLPS.dll"
$AzureMLPSPath
Unblock-File $AzureMLPSPath
Import-Module $AzureMLPSPath

# Zip Module Files
Add-Type -assembly "system.io.compression.filesystem"

$destination = Join-Path $source "..\..\module.zip"

If(Test-path $destination) {Remove-item $destination}

[io.compression.zipfile]::CreateFromDirectory($Source, $destination) 

## Upload Zipped Modules to Azure ML
#New-AmlCustomModule -CustomModuleZipFileName $destination

## Get test experiment
#$exp = Get-AmlExperiment | where Description -eq 'Hello World Test Experiment'

## Update Test Experiement
#Update-AmlExperimentModule -ExperimentId $exp.ExperimentId -All

## Run Test Experiment 
#Start-AmlExperiment -ExperimentId $exp.ExperimentId

## Get Status of Test Experiment
#$exp = Get-AmlExperiment | where Description -eq 'Hello World Test Experiment'
#$exp.Status
#$status = $exp.Status.StatusCode

# If Status good upload to main workspace and update Dev Experiments

Get-AmlWorkspace -ConfigFile $ConfigFile
New-AmlCustomModule -ConfigFile $ConfigFile -CustomModuleZipFileName $destination
# Update Experiments
# Could not get Term Clustering experiment by description...
#$exp = Get-AmlExperiment -ConfigFile $ConfigFile | where Description -eq 'Theme Clustering'
#Update-AmlExperimentModule -ConfigFile $ConfigFile -ExperimentId $exp.ExperimentId -All
#$exp = Get-AmlExperiment -ConfigFile $ConfigFile | where Description -eq 'Theme Detection Scoring'
#Update-AmlExperimentModule -ConfigFile $ConfigFile -ExperimentId $exp.ExperimentId -All
#$exp = Get-AmlExperiment -ConfigFile $ConfigFile | where Description -eq 'Theme Detection Training'
#Update-AmlExperimentModule -ConfigFile $ConfigFile -ExperimentId $exp.ExperimentId -All

# Update webservice/endpoint
# Deploy Web Service from the Predictive Experiment
# DOESNT WORK as of 7/14/2016, but may work now...
# Server Issue where it creates copy of existing webservice instead of updating
#$webService = New-AmlWebService -PredictiveExperimentId $exp.ExperimentId
# Display newly created Web Service
#$webService

#Add-AmlWebServiceEndpoint -WebServiceId $webService.Id -EndpointName 'newep01' -Description 'New Endpoint 01' -ThrottleLevel 'Low' -MaxConcurrentCalls 20


# If status bad raise build error

# Attempt to give up lock on dll
# doesn't work...
Unblock-File $AzureMLPSPath