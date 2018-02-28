<#
.SYNOPSIS
    Re-Create a Virtual Machine from an OS Disk Snapshot.

.DESCRIPTION
    Re-Creates a Virtual Machine that is defined using Managed Disks using a previously capture snapshot disk.

.PARAMETER SubscriptionName
    Azure Subscription Name that has the Virtual Machine which will be recreated.

.PARAMETER SourceResourceGroup
    The Resource Group Name in which the Virtual Machine belongs too.

.PARAMETER SourceVMName
    The name of the Virtual Machine that will recreated.

.PARAMETER TargetResourceGroup
    The Resource Group where the Virtual Machine OS Disk snapshot exists.

.PARAMETER SnapShotName
    The name of the saved OS Disk snapshot to re-create the Virtual Machine with.

.PARAMETER UserName
    The Azure Active Directory User Name that has the necessary permissions to recreate a Virtual Machine from a snapshot.
	The user must have Contributor permissions Resource Groups used for this operation.
	This parameter is optional, if not provided the script will prompt for user credentials before executing.

.PARAMETER Password
	The Azure Active Directory User Name password.
	This parameter is optional, if not provided the script will prompt for the password before executing.

.EXAMPLE
    .\ReCreateVMFromSnapShot.ps1 -SubscriptionName "AzureSubscriptionName" -SourceResourceGroup "VMResourceGroup" -SourceVMName "VMName" -TargetResourceGroup "CopiedDiskResourceGroup" -SnapShotName "NameOfExistingSnapShot" 
    <Description of example>

.NOTES
    Author: David Pitcher
    Date:   February 28, 2018    
#>
[CmdletBinding()]
Param(
	[Parameter(ParameterSetName="NoCredentials", Mandatory=$true, Position=0)]
	[Parameter(ParameterSetName="WithCredentials", Mandatory=$true, Position=0)]
	[string] $SubscriptionName,

	[Parameter(ParameterSetName="NoCredentials", Mandatory=$true, Position=1)]
	[Parameter(ParameterSetName="WithCredentials", Mandatory=$true, Position=1)]
	[string] $SourceResourceGroup,

	[Parameter(ParameterSetName="NoCredentials", Mandatory=$true, Position=1)]
	[Parameter(ParameterSetName="WithCredentials", Mandatory=$true, Position=1)]
	[string] $SourceVMName,

	[Parameter(ParameterSetName="NoCredentials", Mandatory=$true, Position=2)]
	[Parameter(ParameterSetName="WithCredentials", Mandatory=$true, Position=2)]
	[string] $TargetResourceGroup,

	[Parameter(ParameterSetName="NoCredentials", Mandatory=$true, Position=3)]
	[Parameter(ParameterSetName="WithCredentials", Mandatory=$true, Position=3)]
	[string] $SnapShotName,

	[Parameter(ParameterSetName="WithCredentials", Mandatory=$true, Position=4)]
	[string] $UserName,
	 	
	[Parameter(ParameterSetName="WithCredentials", Mandatory=$true, ValueFromPipeline=$true, Position=5)]
	[Security.SecureString] $Password
)
#region Script Setup
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[string]$ScriptPath = Split-Path -Path $MyInvocation.MyCommand.Path
#endregion

#region Connect to Azure
#---------------------------------------------
# Login into Azure Account using the provided credentials
#---------------------------------------------

if($UserName -and $Password)
{
	$azureCredential = New-Object System.Management.Automation.PSCredential($UserName, $Password) -ErrorAction Stop
}
else
{
	$azureCredential = Get-Credential -Message "Enter your Azure Subscription User Account" -ErrorAction Stop
}

if($azureCredential)
{
	Login-AzureRmAccount -Credential $azureCredential -ErrorAction Stop 
}
#---------------------------------------------

#---------------------------------------------
# Set Azure Subscription Context
# Set the correct subscription context to the correct one
# in case a user has access to multiple subscriptions.
#---------------------------------------------
if(!(Get-AzureRmSubscription -WarningAction SilentlyContinue | Where {$_.Name -eq $SubscriptionName}))
{
	throw ("Unable to find the Azure Subscription '{0}'. Verify the subscription name and that you have permissions to access this subscription" -f $SubscriptionName)
}
$azureRmContext = Set-AzureRmContext -SubscriptionName $SubscriptionName
Write-Output("Azure sbuscription context now assigned to '{0}' - {1}`n" -f $azureRmContext.Subscription.Name, $(Get-Date -Format FileDateTimeUniversal) )
#---------------------------------------------
#endregion

#region Get VM Information
#-------------------------------------------------
# Get VM and enumerate all the VM assets needed to recreate
# the VM from a Snapshot of the Managed OS Disk
#-------------------------------------------------
if(!(Get-AzureRmVm -ResourceGroupName $SourceResourceGroup | Where-Object {$_.Name -eq $SourceVMName}))
{
	throw("Could not locate the VM {0}" -f $SourceVMName)
}
$vm = Get-AzureRmVm -ResourceGroupName $SourceResourceGroup | Where-Object {$_.Name -eq $SourceVMName}
$vmStatus = $((Get-AzureRmVm -ResourceGroupName $SourceResourceGroup -Name $SourceVMName -Status).Statuses | Where-Object {$_.Code -like "PowerState*"}).Code
$oldVm = [PSCustomObject]@{
	Name = $vm.Name
	Location = $vm.Location
	Size = $vm.HardwareProfile.VmSize
	Nics = $vm.NetworkProfile.NetworkInterfaces
	DiagEnabled = $vm.DiagnosticsProfile.BootDiagnostics.Enabled
	DiagStoreUri = $vm.DiagnosticsProfile.BootDiagnostics.StorageUri
	OsDiskName = $vm.StorageProfile.OsDisk.Name
	OsType = $vm.StorageProfile.OsDisk.OsType
	DataDisks = $vm.StorageProfile.DataDisks
	IsRunning = $vmStatus -match "running"
}
Write-Output("Begin Restore of VM '{0}' - {1}`nCaptured VM Details:" -f $SourceVMName, $(Get-Date -Format FileDateTimeUniversal))
Write-Output $oldVm
#--------------------------------------------------
#endregion

#region Delete VM
#---------------------------------------------------
# Delete just the VM and leave all resources in place
#----------------------------------------------------
Write-Output("Starting Deletion of VM '{0}' - {1}`n" -f $oldVm.Name, $(Get-Date -Format FileDateTimeUniversal))
Remove-AzureRmVM -ResourceGroupName -$SourceResourceGroup -Name $SourceVMName -Force
#Read-Host "Press Enter after VM is deleted" | Out-Null
Write-Output("Finished Deletetion of VM '{0}' - `n" -f $oldVm.Name, $(Get-Date -Format FileDateTimeUniversal))
#endregion

#region Create Copy of SnapShot
#---------------------------------------------------
# Locate the VM SnapShot and Create a new Managed Disk 
# the snapshot.
#----------------------------------------------------
$vmSnapShot = Get-AzureRmSnapshot -ResourceGroupName $TargetResourceGroup | Where-Object {$_.Name -eq $SnapShotName}
if(!$vmSnapShot)
{
	throw("Could not locate the Managed Disk Snapshot {0}" -f $SnapShotName)
}
Write-Output("Starting Creation of New VM OS Disk - {0}`n" -f $(Get-Date -Format FileDateTimeUniversal))
$vmDiskConfig = New-AzureRmDiskConfig -Location $vmSnapShot.Location -SourceResourceId $vmSnapShot.Id -CreateOption Copy
$vmOsDisk = New-AzureRmDisk -Disk $vmDiskConfig -DiskName $("{0}-{1}-{2}" -f $oldVm.Name, "OSDisk", $(Get-Date -UFormat "%Y-%m-%d-%H%M%S")) -ResourceGroupName $SourceResourceGroup
Write-Output("Finished Creation of New VM OS Disk '{0}' from the Snapshot '{1}' - {2}`n" -f $vmOsDisk.Name, $vmSnapShot.Name, $(Get-Date -Format FileDateTimeUniversal))
#----------------------------------------------------
#endregion

#region Create VM
#----------------------------------------------------
# Re-Create the VM with the Snapshot and previous 
# resources
#----------------------------------------------------
$vmConfig = New-AzureRmVMConfig -VMName $oldVm.Name -VMSize $oldVm.Size

Write-Output("Starting VM Network Configuration - {0}`n" -f $(Get-Date -Format FileDateTimeUniversal))
foreach($nic in $oldVm.Nics)
{
	$vmConfig = Add-AzureRmVMNetworkInterface -VM $vmConfig -Id $nic.Id
}
Write-Output("Finished VM Network Configuration - {0}`n" -f $(Get-Date -Format FileDateTimeUniversal))

Write-Output("Starting VM OS Disk Configuration - {0}`n" -f $(Get-Date -Format FileDateTimeUniversal))
switch($oldVm.OsType)
{
	"Windows" {
		$vmConfig = Set-AzureRmVmOsDisk -VM $vmConfig -ManagedDiskId $vmOsDisk.Id -CreateOption Attach -Windows
		break
	}
	"Linux" {
		$vmConfig = Set-AzureRmVmOsDisk -VM $vmConfig -ManagedDiskId $vmOsDisk.Id -CreateOption Attach -Linux
		break
	}
	default {
		throw("The specified OS Type '{0}' is not supported." -f $oldVm.OsType)
	}
}
Write-Output("Finished VM OS Disk Configuration - {0}`n" -f $(Get-Date -Format FileDateTimeUniversal))

Write-Output("Starting VM Data Disk Configuration - {0}`n" -f $(Get-Date -Format FileDateTimeUniversal))
foreach($dataDisk in $oldVm.DataDisks)
{
	$managedDataDisk = Get-AzureRmDisk -ResourceGroupName $SourceResourceGroup | Where-Object {$_.Name -eq $dataDisk.Name}
	$vmConfig = Add-AzureRmVMDataDisk -VM $vmConfig -ManagedDiskId $managedDataDisk.Id -Lun $dataDisk.Lun -CreateOption Attach 
}
Write-Output("Finished VM Data Disk Configuration - {0}`n" -f $(Get-Date -Format FileDateTimeUniversal))

if($oldVm.DiagEnabled)
{
	Write-Output("Starting VM Boot Diagnostic Configuration - {0}`n" -f $(Get-Date -Format FileDateTimeUniversal))
	$diageStoreAccount = Get-AzureRmStorageAccount | Where-Object {$_.PrimaryEndpoints.Blob -eq $oldVm.DiagStoreUri}
	Set-AzureRmVMBootDiagnostics -VM $vmConfig -Enable -ResourceGroupName $diageStoreAccount.ResourceGroupName -StorageAccountName $diageStoreAccount.StorageAccountName
	Write-Output("Finished VM Boot Diagnostic Configuration to Storage Uri '{0}' - {1}`n" -f $oldVm.DiagStoreUri, $(Get-Date -Format FileDateTimeUniversal))
}

Write-Output("Starting Provisioing of New VM '{0}' - {1}`n" -f $oldVm.Name, $(Get-Date -Format FileDateTimeUniversal) )
$vm = New-AzureRmVm -VM $vmConfig -ResourceGroupName $SourceResourceGroup -Location $oldVm.Location
Write-Output("Finished Provisioning of New VM '{0}' - {1}`n" -f $oldVm.Name, $(Get-Date -Format FileDateTimeUniversal))

Write-Output("Complete Restore of VM '{0}' using OS Disk Snapshot '{1}' - {2}`n" -f $oldVm.Name, $vmSnapShot.Name, $(Get-Date -Format FileDateTimeUniversal))
#-------------------------------------------------------
#endregion
