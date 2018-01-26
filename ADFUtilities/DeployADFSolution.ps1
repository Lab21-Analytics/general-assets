# Define Variables

param(
       [string] $ADFName = $(read-host "Please specify the ADFName:"),
       [string] $configFile = $(read-host "Please specify Config File Name:"),
       [string] $subscriptionName = “RTG-US-TestDev”,
       [string] $resourceGroup = "JaysRetailStoreGroup"
)
 

# Login to Azure Account
Login-AzureRmAccount

# Switch to Microsoft Subscription
Get-AzureRmSubscription –SubscriptionName $subscriptionName | Select-AzureRmSubscription

# Access specific Data Factory
Get-AzureRmDataFactory -ResourceGroupName $resourceGroup -Name $ADFName

# Get pipeline info, but can't get json source
#Parameter Set: ByFactoryName
#Get-AzureRmDataFactoryPipeline -ResourceGroupName $resourceGroup -DataFactoryName $ADFName

# Deploy ADF Solution
#======================#

# Get source files
# $PSScriptRoot  + '../TEIADF

$repo = "Microsoft%20Retail%20Store%20Customer%20Insights%20through%20NLP"
$path = "$env:homepath\Documents\ps"
$repoPath = $path+"\"+$repo

if(!(Test-Path $repoPath))
{
    if(!(Test-Path $path)) { mkdir $path }
    cd $path
    git clone https://mrscustomerinsights.visualstudio.com/_git/Microsoft%20Retail%20Store%20Customer%20Insights%20through%20NLP -q
} else 
{
    cd $repoPath
    git pull origin master 
}

cd..

$sources = Get-ChildItem -Path "$repoPath\TEIADF\*.json" | Where-Object {$_.Name -notmatch "Config.json"}

# Fill in parameters
# read config file
# pass config file in the command line and store in a tempvariable
$Config = ConvertFrom-Json -InputObject (Gc "$repoPath\TEIADF\$configFile.json" -Raw)
# Add "EnvironmentLower" property to Config.Metadata object
$Config.Metadata | Add-Member -MemberType NoteProperty -Name EnvironmentLower -Value $Config.Metadata.Environment.ToLower()

#Add "DataSourceNameLower" property to Config.MetaData object
$Config.Metadata | Add-Member -MemberType NoteProperty -Name DataSourceNameLower -Value $Config.Metadata.DataSourceName.ToLower()  


# Delete Pipelines
$sources | Where-Object {$_.FullName -Like "*Pipeline*"} | ForEach-Object{
    $File=$_.FullName

    # Read file as text and expand variables $($Config.variableName)
    $configuredFileContents = $ExecutionContext.InvokeCommand.ExpandString([IO.File]::ReadAllText($File))
	$FileConfig = ConvertFrom-Json -InputObject $configuredFileContents
        
	# If pipeline exists, delete from azure
	IF(Get-AzureRmDataFactoryPipeline -ResourceGroupName $resourceGroup -DataFactoryName $ADFName -Name $FileConfig.Name) {
		Remove-AzureRmDataFactoryPipeline -ResourceGroupName $resourceGroup -DataFactoryName $ADFName -Name $FileConfig.Name
	}
}

# Delete Datasets
$sources | Where-Object {$_.FullName -Like "*Dataset*"} | ForEach-Object{
    $File=$_.FullName

    # Read file as text and expand variables $($Config.variableName)
    $configuredFileContents = $ExecutionContext.InvokeCommand.ExpandString([IO.File]::ReadAllText($File))
	$FileConfig = ConvertFrom-Json -InputObject $configuredFileContents
        
	# If dataset exists, delete from azure   
	IF(Get-AzureRmDataFactoryDataset -ResourceGroupName $resourceGroup -DataFactoryName $ADFName -Name $FileConfig.Name) {
		Remove-AzureRmDataFactoryDataset -ResourceGroupName $resourceGroup -DataFactoryName $ADFName -Name $FileConfig.Name
	}
}

# Delete Linked Services
$sources | Where-Object {$_.FullName -Like "*LinkedService*"} | ForEach-Object{
    $File=$_.FullName

    # Read file as text and expand variables $($Config.variableName)
    $configuredFileContents = $ExecutionContext.InvokeCommand.ExpandString([IO.File]::ReadAllText($File))
	$FileConfig = ConvertFrom-Json -InputObject $configuredFileContents
        
	# If linked service exists, delete from azure   
	IF(Get-AzureRmDataFactoryLinkedService -ResourceGroupName $resourceGroup -DataFactoryName $ADFName -Name $FileConfig.Name) {
		Remove-AzureRmDataFactoryLinkedService -ResourceGroupName $resourceGroup -DataFactoryName $ADFName -Name $FileConfig.Name
	}
}


# Create linked services
$sources | Where-Object {$_.FullName -Like "*LinkedService*"} | ForEach-Object{        
    $File=$_.FullName

    if(($Config.Metadata.LinkedServiceType.ToLower() -eq "azuresqldatabase") -and ($File.Contains("OnPremiseLinkedService.json"))){
        #$File
        return
    }

	if(($Config.Metadata.LinkedServiceType.ToLower() -eq "onpremisessqlserver") -and ($File.Contains("AzureSqlLinkedService.json"))){
        #$File
        return
    }


    Try
    {
        # Read file as text and expand variables $($Config.variableName)
        $configuredFileContents = $ExecutionContext.InvokeCommand.ExpandString([IO.File]::ReadAllText($File))
        #$configuredFileContents
        $tempFile = New-TemporaryFile
        # Pipe configured file to temp
        $configuredFileContents | Out-File $tempFile.FullName
        # Deploy to Azure        
        New-AzureRmDataFactoryLinkedService -ResourceGroupName $resourceGroup -DataFactoryName $ADFName -File $tempFile.FullName -ErrorAction Stop
        Remove-Item $tempFile.FullName -Force
    }
    Catch
    {
        $Host.UI.WriteErrorLine($_.Exception.ItemName)
        $Host.UI.WriteErrorLine($_.Exception.Message)
        Break
    }
}

# Create datasets
$sources | Where-Object {$_.FullName -Like "*Dataset*"} | ForEach-Object{
    $File=$_.FullName
    Try
    {    
        # Read file as text and expand variables $($Config.variableName)
        $configuredFileContents = $ExecutionContext.InvokeCommand.ExpandString([IO.File]::ReadAllText($File))
        #$configuredFileContents
        $tempFile = New-TemporaryFile
        # Pipe configured file to temp
        $configuredFileContents | Out-File $tempFile.FullName
        # Deploy to Azure        
        New-AzureRmDataFactoryDataset -ResourceGroupName $resourceGroup -DataFactoryName $ADFName -File $tempFile.FullName -ErrorAction Stop
        Remove-Item $tempFile.FullName -Force        
    }
    Catch
    {
        $Host.UI.WriteErrorLine($_.Exception.ItemName)
        $Host.UI.WriteErrorLine($_.Exception.Message)
        Break
    }
}

# Create pipelines
$sources | Where-Object {$_.FullName -Like "*Pipeline*"} | ForEach-Object{
    $File=$_.FullName
    Try
    {
        # Read file as text and expand variables $($Config.variableName)
        $configuredFileContents = $ExecutionContext.InvokeCommand.ExpandString([IO.File]::ReadAllText($File))
        #$configuredFileContents
        $tempFile = New-TemporaryFile
        # Pipe configured file to temp
        $configuredFileContents | Out-File $tempFile.FullName
        # Deploy to Azure        
        New-AzureRmDataFactoryPipeline -ResourceGroupName $resourceGroup -DataFactoryName $ADFName -File $tempFile.FullName -ErrorAction Stop
        Remove-Item $tempFile.FullName -Force            
    }
    Catch
    {
        $Host.UI.WriteErrorLine($_.Exception.ItemName)
        $Host.UI.WriteErrorLine($_.Exception.Message)
        Break
    }
}