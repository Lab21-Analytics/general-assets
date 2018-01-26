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
	[string] $SourceManagedDiskName,

	[Parameter(ParameterSetName="NoCredentials", Mandatory=$true, Position=2)]
	[Parameter(ParameterSetName="WithCredentials", Mandatory=$true, Position=2)]
	[string] $TargetResourceGroup,

	[Parameter(ParameterSetName="NoCredentials", Mandatory=$true, Position=3)]
	[Parameter(ParameterSetName="WithCredentials", Mandatory=$true, Position=3)]
	[string] $TargetResourceGroupLocation,

	[Parameter(ParameterSetName="NoCredentials", Mandatory=$true, Position=1)]
	[Parameter(ParameterSetName="WithCredentials", Mandatory=$true, Position=1)]
	[string] $TargetManagedDiskName,

	[Parameter(ParameterSetName="WithCredentials", Mandatory=$true, Position=2)]
	[string] $UserName,
	 	
	[Parameter(ParameterSetName="WithCredentials", Mandatory=$true, ValueFromPipeline=$true, Position=3)]
	[Security.SecureString] $Password
)

#region Script Setup
Set-StrictMode -Version Latest
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
Write-Host("Azure sbuscription context now assigned to '{0}'." -f $azureRmContext.Subscription.Name)
#---------------------------------------------
#endregion

#region Copy Managed Disk
$sourceDisk = Get-AzureRMDisk -ResourceGroupName $SourceResourceGroup -DiskName $SourceManagedDiskName
$newDiskConfig = New-AzureRmDiskConfig -SourceResourceId $sourceDisk.Id -Location $TargetResourceGroupLocation -CreateOption Copy 
$newDisk = New-AzureRmDisk -Disk $newDiskConfig -DiskName $TargetManagedDiskName -ResourceGroupName $TargetResourceGroup
#endregion