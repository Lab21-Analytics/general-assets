Azure ML Utilties
==================

Is a WIP Visual Studio Power Shell project containing scripts for managing AML Studio Experiment Graphs. Scripts are built using [Azure Machine Learing Power Shell (AzureMLPS)](https://github.com/hning86/azuremlps) commandlets.

## !Warning!
Use scripts at your own risk! Many of them could corrupt your AML Studio Workspace. The script "BackupExperimentGraphs.ps1" is the safest script that will just read and download all the experiment graphs from a configured subscription. The rest of the scripts will write to your workspace and don't have safety mechanisms.

## Configuration
See configuration section of [AzureMLPS README](https://github.com/hning86/azuremlps)