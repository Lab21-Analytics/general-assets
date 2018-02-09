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

	[Parameter(ParameterSetName="WithCredentials", Mandatory=$true, Position=5)]
	[string] $UserName,
	 	
	[Parameter(ParameterSetName="WithCredentials", Mandatory=$true, ValueFromPipeline=$true, Position=6)]
	[Security.SecureString] $Password
)

# .\CreateVMOSSnapShot.ps1 -SubscriptionName "Microsoft Azure Enterprise" -SourceResourceGroup "rgname" -SourceVMName "vmname" -TargetResourceGroup "targetrg" -TargetResourceGroupLocation "westus2" -UserName "username@domain.onmicrosoft.com"

#region Script Setup
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[string]$ScriptPath = Split-Path -Path $MyInvocation.MyCommand.Path
#endregion

#region Connect to Azure
#---------------------------------------------
# Login into Azure Account
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
#---------------------------------------------
if(!(Get-AzureRmSubscription -WarningAction SilentlyContinue | Where {$_.Name -eq $SubscriptionName}))
{
	throw ("Unable to find the Azure Subscription '{0}'. Verify the subscription name and that you have permissions to access this subscription" -f $SubscriptionName)
}
$azureRmContext = Set-AzureRmContext -SubscriptionName $SubscriptionName
Write-Output("Azure sbuscription context now assigned to '{0}'.`n" -f $azureRmContext.Subscription.Name)
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
Write-Output("Begin Taking Snapshot VM '{0}' `nCaptured VM Details:" -f $SourceVMName)
Write-Output $oldVm
#--------------------------------------------------
#endregion

#region Stop VM
#--------------------------------------------------
# Stop the Azure VM before taking a snap shot of the OS Disk
#--------------------------------------------------
if($oldVm.IsRunning)
{
	Write-Output("Begin Stopping VM '{0}'.`n" -f $oldVm.Name)
	Stop-AzureRmVM -ResourceGroupName $SourceResourceGroup -Name $SourceVMName -Force
	Write-Output("VM '{0}' has been successfully stopped.`n" -f $oldVm.Name)
}
#--------------------------------------------------
#endregion

#region Create SnapShot
#---------------------------------------------------
# Locate the VM OS Managed Disk and create a snapshot of that
# disk.  Snapshot name is created by using the VM Name, fixed string
# of "OSDisk" and a date/time stamp YYYY-MM-DD-24HRMMSS
#----------------------------------------------------
Write-Output("Starting Creation of a VM OS Disk Snapshot.`n")
$vmOsManagedDisk = Get-AzureRmDisk -ResourceGroupName $SourceResourceGroup | Where-Object {$_.Name -eq $oldVm.OsDiskName}
if(!$vmOsManagedDisk)
{
	throw("Could not locate a managed disk for the VM {0}" -f $SourceVMName)
}
$vmSnapShotName = $("{0}-{1}-{2}" -f $SourceVMName, "OSDisk", $(Get-Date -UFormat "%Y-%m-%d-%H%M%S") )
$diskSnapShotConfig = New-AzureRmSnapshotConfig -SourceUri $vmOsManagedDisk.Id -CreateOption Copy -Location $TargetResourceGroupLocation
$diskSnapShot = New-AzureRmSnapshot -Snapshot $diskSnapShotConfig -SnapshotName $vmSnapShotName -ResourceGroupName $TargetResourceGroup
Write-Output("Finished Creation of the Snapshot '{0}' from the VM OS Disk '{1}'.`n" -f $vmSnapShotName, $oldVm.OsDiskName)
#----------------------------------------------------
#endregion


#region Start VM
#--------------------------------------------------
# Stop the Azure VM before taking a snap shot of the OS Disk
#--------------------------------------------------
Write-Output("Begin Starting VM '{0}'.`n" -f $oldVm.Name)
Start-AzureRmVM -ResourceGroupName $SourceResourceGroup -Name $SourceVMName
Write-Output("VM '{0}' has been successfully started.`n" -f $oldVm.Name)
#--------------------------------------------------
#endregion

Write-Output("VM Snapshot Process Successfully Completed.")
