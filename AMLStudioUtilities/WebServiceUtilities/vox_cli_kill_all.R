#!/usr/bin/env Rscript
## --
## script for checking the status of endpoints for various tenants and various environments
## --
args <- commandArgs(trailingOnly=TRUE);
if ( length(args) < 3 ) stop('No arguments (envir, tenants, local)') else print(paste('ARGS (envir, tenants, local)',paste(args,collapse=' ')));
## --
source('vox_cli_main.R'); VOX_SLEEP_ <<- 0;
## --
results <- vox_cli_diagnose_all(environments=eval(parse(text=args[1])),tenants=eval(parse(text=args[2])),get_counts=T,kill_jobs=T,local=as.numeric(args[3]));
## --
print('-----');
print(results);
print('-----');
## --

