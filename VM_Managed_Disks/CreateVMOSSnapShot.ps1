<#
.SYNOPSIS
    Create a Virtual Machine OS Disk Snapshot.

.DESCRIPTION
    Creates a Snapshot of the OS Disk for a Azure Virtual Machine that is defined using Managed Disks.

.PARAMETER SubscriptionName
    Azure Subscription Name that has the Virtual Machine in which the snapshot will be performed on.

.PARAMETER SourceResourceGroup
    The Resource Group Name in which the Virtual Machine belongs too.

.PARAMETER SourceVMName
    The name of the Virtual Machine that will have OS snapshot taken.

.PARAMETER TargetResourceGroup
    The Resource Group where the Virtual Machine OS Disk snapshot will be saved.

.PARAMETER TargetResourceGroupLocation
    The Region for the Target Resource Group where the Virtual Machine OS Disk snapshot will be saved.

.PARAMETER UserName
    The Azure Active Directory User Name that has the necessary permissions to perform the Virtual Machine Snapshot.
	The user must have Contributor permissions Resource Groups used for this operation.
	This parameter is optional, if not provided the script will prompt for user credentials before executing.

.PARAMETER Password
	The Azure Active Directory User Name password.
	This parameter is optional, if not provided the script will prompt for the password before executing.

.EXAMPLE
    .\CreateVMOSSnapShot.ps1 -SubscriptionName "AzureSubscriptionName" -SourceResourceGroup "VMResourceGroup" -SourceVMName "VMName" -TargetResourceGroup "CopiedDiskResourceGroup" -TargetResourceGroupLocation "CopiedDiskRGLocation" 
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
	[string] $TargetResourceGroupLocation,

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
Write-Output("Azure sbuscription context now assigned to '{0}' - {1}`n" -f $azureRmContext.Subscription.Name, $(Get-Date -Format FileDateTimeUniversal))
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
Write-Output("Begin Taking Snapshot VM '{0}' - {1}`nCaptured VM Details:" -f $SourceVMName, $(Get-Date -Format FileDateTimeUniversal))
Write-Output $oldVm
#--------------------------------------------------
#endregion

#region Stop VM
#--------------------------------------------------
# Stop the Azure VM before taking a snap shot of the OS Disk
#--------------------------------------------------
if($oldVm.IsRunning)
{
	Write-Output("Begin Stopping VM '{0}' - {1}`n" -f $oldVm.Name, $(Get-Date -Format FileDateTimeUniversal))
	Stop-AzureRmVM -ResourceGroupName $SourceResourceGroup -Name $SourceVMName -Force
	Write-Output("VM '{0}' has been successfully stopped - {1}`n" -f $oldVm.Name, $(Get-Date -Format FileDateTimeUniversal))
}
#--------------------------------------------------
#endregion

#region Create SnapShot
#---------------------------------------------------
# Locate the VM OS Managed Disk and create a snapshot of that
# disk.  Snapshot name is created by using the VM Name, fixed string
# of "OSDisk" and a date/time stamp YYYY-MM-DD-24HRMMSS
#----------------------------------------------------
Write-Output("Starting Creation of a VM OS Disk Snapshot - {0}`n" -f $(Get-Date -Format FileDateTimeUniversal))
$vmOsManagedDisk = Get-AzureRmDisk -ResourceGroupName $SourceResourceGroup | Where-Object {$_.Name -eq $oldVm.OsDiskName}
if(!$vmOsManagedDisk)
{
	throw("Could not locate a managed disk for the VM {0}" -f $SourceVMName)
}
$vmSnapShotName = $("{0}-{1}-{2}" -f $SourceVMName, "OSDisk", $(Get-Date -UFormat "%Y-%m-%d-%H%M%S") )
$diskSnapShotConfig = New-AzureRmSnapshotConfig -SourceUri $vmOsManagedDisk.Id -CreateOption Copy -Location $TargetResourceGroupLocation
$diskSnapShot = New-AzureRmSnapshot -Snapshot $diskSnapShotConfig -SnapshotName $vmSnapShotName -ResourceGroupName $TargetResourceGroup
Write-Output("Finished Creation of the Snapshot '{0}' from the VM OS Disk '{1}' - {2}`n" -f $vmSnapShotName, $oldVm.OsDiskName, $(Get-Date -Format FileDateTimeUniversal))
#----------------------------------------------------
#endregion


#region Start VM
#--------------------------------------------------
# Restart the VM after taking the snapshot
#--------------------------------------------------
if($oldVm.IsRunning)
{
	Write-Output("Begin Starting VM '{0}' - {1}`n" -f $oldVm.Name, $(Get-Date -Format FileDateTimeUniversal))
	Start-AzureRmVM -ResourceGroupName $SourceResourceGroup -Name $SourceVMName
	Write-Output("VM '{0}' has been successfully started - {1}`n" -f $oldVm.Name, $(Get-Date -Format FileDateTimeUniversal))
}
#--------------------------------------------------
#endregion

Write-Output("VM Snapshot Process Successfully Completed - {0}" -f $(Get-Date -Format FileDateTimeUniversal))