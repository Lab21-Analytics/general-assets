## powershell -command - < "vox_cli_refresh_endpoints.ps1"

Unblock-File .\AzureMLPS.dll
Import-Module .\AzureMLPS.dll


$exp = Get-AmlExperiment -ConfigFile 'vox_cli_config_vvd.json' | where Description -eq 'VoX crawling experiment'
echo $exp
Export-AmlExperimentGraph -ConfigFile 'vox_cli_config_vvd.json' -ExperimentId $exp.ExperimentId -OutputFile 'vox_crawling_experiment.json'

$exp = Get-AmlExperiment -ConfigFile 'vox_cli_config_vvd.json' | where Description -eq 'VoX sampling experiment'
echo $exp
Export-AmlExperimentGraph -ConfigFile 'vox_cli_config_vvd.json' -ExperimentId $exp.ExperimentId -OutputFile 'vox_sampling_experiment.json'

$exp = Get-AmlExperiment -ConfigFile 'vox_cli_config_vvd.json' | where Description -eq 'VoX train experiment'
echo $exp
Export-AmlExperimentGraph -ConfigFile 'vox_cli_config_vvd.json' -ExperimentId $exp.ExperimentId -OutputFile 'vox_train_experiment.json'

$exp = Get-AmlExperiment -ConfigFile 'vox_cli_config_vvd.json' | where Description -eq 'VoX train experiment [Predictive Exp.]'
echo $exp
Export-AmlExperimentGraph -ConfigFile 'vox_cli_config_vvd.json' -ExperimentId $exp.ExperimentId -OutputFile 'vox_predictive_experiment.json'

