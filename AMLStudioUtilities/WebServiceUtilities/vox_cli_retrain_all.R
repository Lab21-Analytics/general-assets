#!/usr/bin/env Rscript
## -- 
## script for running jobs for multiple tenant in multiple environments
## -- 
args <- commandArgs(trailingOnly=TRUE);
if ( length(args) < 6 ) stop('No arguments (envir, tenant, file, workers, scan, local)') else print(paste('ARGS (envir, tenant, file, workers, scan, local)',paste(args,collapse=' ')));
if ( as.numeric(args[4]) > 5 ) stop('Too many workers');
## --
source('vox_cli_main.R'); VOX_SLEEP_ <<- 0;
## --
results <- vox_cli_retrain_all(environments=eval(parse(text=args[1])),tenants=eval(parse(text=args[2])),files=eval(parse(text=args[3])),this_total_workers=as.numeric(args[4]),this_scan_prop=as.numeric(args[5]),local=as.numeric(args[6]));
## --
print('-----')
print(results);
print('-----')
## --
