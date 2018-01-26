
## =====================
## == DEPENDENCIES
## =====================

source('../vox-studio/vox-studio-modules/vox_module.R');
if  ( file.exists('vox_cli_envirs_configs.R') ) {
  source('vox_cli_envirs_configs.R');
} else {
  stop(paste('Cannot run command line without proper configuration of',paste(deparse(VOX_ENVIRS),collapse='\n')))
}

## =====================
## == LEVEL -1 FUNCTIONS
## =====================

## =====================
## == HELPER CLI FUNCTION (DESKTOP)
## == RUN DIAGNOSTICS ON ALL TENANTS AND ENVIRONMENTS
## == (get all training and scoring APIs job types counts, recently trained model and the scoring model, 
## == compare them, and kill unwanted jobs)
## == EXAMPLE:
## == source('vox_cli_main.R'); VOX_SLEEP_ <<- 0; results <- vox_cli_diagnose_all(environments='vvd',tenants='vsm',get_counts=TRUE,kill_jobs=FALSE,local=TRUE); print(results);
## =====================

vox_cli_diagnose_all <<- function ( environments = c('prod','ppe','dev','vvd'), tenants = c('devcenter','vod','amp','ust','pac','vsm','demo'), get_counts = FALSE, kill_jobs = FALSE, local = TRUE ) {

  scr_matrix             <- matrix('',length(tenants),length(environments));
  trn_matrix             <- matrix('',length(tenants),length(environments));
  rownames(scr_matrix)   <- tenants;
  colnames(scr_matrix)   <- environments;
  rownames(trn_matrix)   <- tenants;
  colnames(trn_matrix)   <- environments;
  scr_cnt_matrix         <- NULL; 
  trn_cnt_matrix         <- NULL; 
## ------------------------
  for ( environment in environments ) {
    for ( ith_tenant in seq(tenants) ) {
      tenant             <- tenants[ith_tenant];
      print(paste('--- PROCESSING:',environment,tenant,'---'));
      results            <- vox_cli_retrain_and_diagnose(environment,0,0,'',tenant,0,get_counts=get_counts,kill_jobs=kill_jobs,local=local);
      if ( length(results$rrs_result) && length(results$rrs_result[[1]]) > 1 ) {
	model_as_md5     <- results$rrs_result[[1]][[2]][[3]][[1]][2];
	scr_matrix[tenant,environment] <- model_as_md5;
      }
      if ( length(results$perf_data) ) {
	model_as_md5     <- as.character(results$perf_data$muid)[1];
	trn_matrix[tenant,environment] <- model_as_md5;
      }
      if ( get_counts ) {
	trn_cnt_matrix   <- rbind(trn_cnt_matrix,results$train_jobs_counts);
	scr_cnt_matrix   <- rbind(scr_cnt_matrix,results$score_jobs_counts);
	rownames(trn_cnt_matrix) <- c(rownames(trn_cnt_matrix)[-nrow(trn_cnt_matrix)],paste(environment,tenant));
	rownames(scr_cnt_matrix) <- c(rownames(scr_cnt_matrix)[-nrow(scr_cnt_matrix)],paste(environment,tenant));
      }
    }
  }
## ------------------------
  return(list(score_models=scr_matrix,train_models=trn_matrix,score_jobs=scr_cnt_matrix,train_jobs=trn_cnt_matrix));

}

## =====================
## == HELPER CLI FUNCTION (DESKTOP)
## == RUN RETRAIN ON ALL TENANTS AND ENVIRONMENTS
## == (retrain on all APIs with corresponding data files)
## == EXAMPLE:
## == source('vox_cli_main.R'); VOX_SLEEP_ <<- 0; results <- vox_cli_retrain_all(environments=c('vvd'),tenants=c('vsm'),files=c('vox-training/vsm-training-ver101L1.csv'),this_total_workers=1,this_scan_prop=100,local=TRUE); print(results);
## =====================

vox_cli_retrain_all <<- function ( environments = c('prod','ppe','dev','vvd'), tenants = c('vod','amp','ust','pac','vsm','demo'), files = c('vox-training/vod-training-ver2241L2.csv','vox-training/amp-training-ver400L2.csv','vox-training/ust-training-ver399L1.csv','vox-training/pac-training-ver400L1.csv','vox-training/vsm-training-ver101L1.csv','vox-training/demo-training-ver20L1.csv'), this_total_workers = 1, this_scan_prop = 100, local = TRUE, get_counts = TRUE ) {

  scr_matrix             <- matrix('',length(tenants),length(environments));
  trn_matrix             <- matrix('',length(tenants),length(environments));
  rownames(scr_matrix)   <- tenants;
  colnames(scr_matrix)   <- environments;
  rownames(trn_matrix)   <- tenants;
  colnames(trn_matrix)   <- environments;
  scr_cnt_matrix         <- NULL; 
  trn_cnt_matrix         <- NULL; 
## ------------------------
  for ( environment in environments ) {
    for ( ith_tenant in seq(tenants) ) {
      tenant             <- tenants[ith_tenant];
      file               <- files[ith_tenant];
      print(paste('--- PROCESSING:',environment,tenant,file,'---'));
      results            <- vox_cli_retrain_and_diagnose(environment,this_total_workers,this_scan_prop,file,tenant,0,get_counts=get_counts,kill_jobs=TRUE,local=local);
      if ( length(results$rrs_result) && length(results$rrs_result[[1]]) > 1 ) {
	model_as_md5     <- results$rrs_result[[1]][[2]][[3]][[1]][2];
	scr_matrix[tenant,environment] <- model_as_md5;
      }
      if ( length(results$perf_data) ) {
	model_as_md5     <- as.character(results$perf_data$muid)[1];
	trn_matrix[tenant,environment] <- model_as_md5;
      }
      if ( get_counts ) {
	trn_cnt_matrix   <- rbind(trn_cnt_matrix,results$train_jobs_counts);
	scr_cnt_matrix   <- rbind(scr_cnt_matrix,results$score_jobs_counts);
	rownames(trn_cnt_matrix) <- c(rownames(trn_cnt_matrix)[-nrow(trn_cnt_matrix)],paste(environment,tenant));
	rownames(scr_cnt_matrix) <- c(rownames(scr_cnt_matrix)[-nrow(scr_cnt_matrix)],paste(environment,tenant));
      }
    }
  }
## ------------------------
  return(list(score_models=scr_matrix,train_models=trn_matrix,score_jobs=scr_cnt_matrix,train_jobs=trn_cnt_matrix));

}

## =====================
## == LEVEL 0 FUNCTIONS
## =====================

## =====================
## == HELPER CLI FUNCTION (DESKTOP)
## == RUN RETRAIN AND DIAGNOSTICS
## == ON VARIOUS ENPOINTS AND ENVIRONMENTS
## == EXAMPLE:
## == source('vox_cli_main.R'); res <- vox_cli_retrain_and_diagnose('dev',0,0,'vox-training/pac-training-ver400L1.csv','pac',0,F,F);
## =====================

vox_cli_retrain_and_diagnose <<- function ( environment = 'dev', this_total_workers = 0, this_scan_prop = 0, this_train_path = 'vox-training/ust-training-ver300L1.csv', this_tenant_name = 'ust', this_update_min_f1 = 0.001, get_counts = TRUE, kill_jobs = FALSE, local = TRUE ) {

  http_url                 <- VOX_ENVIRS[[environment]]$http_url;
  storage_key              <- VOX_ENVIRS[[environment]]$storage_key;
  storage_name             <- VOX_ENVIRS[[environment]]$storage_name;
  workspace_key            <- VOX_ENVIRS[[environment]]$workspace_key;
  workspace_id             <- VOX_ENVIRS[[environment]]$workspace_id;
  workspace_auth_header    <- paste('Bearer',workspace_key,sep=' ');
  setup_crc32              <- paste(environment,'_cli',sep='');
  train_version            <- sub('\\d-\\d\\d$','0-00',gsub('\\W+','-',.POSIXct(Sys.time(),tz='UTC')));
  perf_data                <- list();
  train_jobs_counts        <- list();
  score_jobs_counts        <- list();
  rrs_result               <- list();
  model_as_md5_new         <- 'NA';
  new_f1_score             <- 0; if ( local ) source('vox_cli_https_request.R');
## ------------------------
## - - - - JOB COUNTS
  if ( is.null(workspace_id) ) stop(paste('Environment',environment,'does not exists!'));
  remote_worker_conf       <- configure_worker_from_urls_(http_url,workspace_auth_header,this_tenant_name,workspace_id);
  train_url                <- remote_worker_conf$train_url;
  train_key                <- remote_worker_conf$train_key;
  train_auth_header        <- paste('Bearer',train_key,sep=' ');
  if ( kill_jobs || get_counts ) {
    train_jobs_counts      <- get_jobs_counts_(http_url,train_url,train_auth_header,kill_jobs,-1,-1);
  }
  score_url                <- remote_worker_conf$score_url;
  score_key                <- remote_worker_conf$score_key;
  score_auth_header        <- paste('Bearer',score_key,sep=' ');
  if ( get_counts ) {
    score_jobs_counts      <- get_jobs_counts_(http_url,sub('execute','jobs',score_url),score_auth_header,kill_jobs,-1,-1);
  }
## - - - - - - - - - - - -
## - - - - RUN RETRAIN WITH AUTOUPDATE
  if ( this_total_workers && this_scan_prop ) {
    print(paste('-- Trying to run a retrain job for tenant',this_tenant_name,'envir',environment,'--'));
    if ( length(train_jobs_counts) && train_jobs_counts['Running'] == 0 ) {
      dataset              <- read.csv(this_train_path,stringsAsFactors=FALSE);
      storage_path         <- upload_dataset_(http_url,workspace_auth_header,this_tenant_name,workspace_id,dataset[,c('fuid','text','labels'),drop=FALSE]);
      print(paste('Data uploaded to',storage_path,'for tenant',this_tenant_name,'envir',environment,'storage name',storage_name));
      json_models          <- run_bes_jobs_(http_url,train_version,train_url,train_auth_header,FALSE,storage_key,storage_name,setup_crc32,this_tenant_name,this_total_workers,-1,train_jobs_counts,this_update_min_f1,this_scan_prop,storage_path,FALSE);
    } else {
      print(paste('Jobs for this tenant are already running or it is unknown',this_tenant_name,train_jobs_counts['Running']));
    }
  } else {
## - - - - - - - - - - - -
## - - - - CHECK LAST TRAIN JOB AND SCORING STATE
    print(paste('-- Trying to run diagnostics for tenant',this_tenant_name,'envir',environment,'--'));
## - - - - LAST ERROR DATA
    last_failed_job        <- attr(train_jobs_counts,'last_failed_job');
    if ( !is.null(last_failed_job) ) {
      result               <- fromJSON(send_request_(http_url,'',train_url,paste('/',last_failed_job,sep=''),train_auth_header,'GET','?api-version=2.0','')$body);
      if ( is.null(attr(train_jobs_counts,'last_finished_time')) || attr(train_jobs_counts,'last_failed_time') > attr(train_jobs_counts,'last_finished_time') ) {
	print(paste('ERROR FROM',attr(train_jobs_counts,'last_failed_time'),'JOB',last_failed_job,'MESSAGE',substring(result$Details,1,9999)));
      }
    }
## - - - - LAST FINISHED RUN
    last_finished_job      <- attr(train_jobs_counts,'last_finished_job');
    if ( !is.null(last_finished_job) ) {
## - - - - LAST TRAIN DATA
      result               <- fromJSON(send_request_(http_url,'',train_url,paste('/',last_finished_job,sep=''),train_auth_header,'GET','?api-version=2.0','')$body);
      relative_location    <- result$Results$performance$RelativeLocation;
      base_location        <- result$Results$performance$BaseLocation;
      sas_blob_token       <- result$Results$performance$SasBlobToken;
      if ( !is.null(relative_location) ) {
	result             <- send_request_(http_url,'',base_location,relative_location,'','GET',sas_blob_token,'')$body;
	if ( length(grep(x=result,pattern='xml version')) == 0 ) {
	  csv_con          <- textConnection(result);
	  perf_data        <- read.csv(csv_con); close(csv_con);
	  model_as_md5_new <- perf_data$muid[1];
	  new_f1_score     <- mean(perf_data$performance..cv.haresults.mean);
	  new_f1_scan      <- mean(perf_data$computations..ratio_scans);
	  print(paste('Found model',model_as_md5_new,'perf',round(new_f1_score,4),'scans',round(new_f1_scan,4),'from job',attr(train_jobs_counts,'last_finished_job'),'finished at',attr(train_jobs_counts,'last_finished_time')))
	} else {
	  print(paste('File',relative_location,'is not accessible'));
	}
      } else {
	print(paste('No performance file detected - only',paste(names(result$Results),collapse=', '),'are present'));
      }
    }
## - - - - LAST SCORE DATA
    rrs_result             <- try(fromJSON(test_new_updated_model_(http_url,score_url,score_auth_header,model_as_md5_new,new_f1_score,0)$body)[[1]]);
  }
  print(paste('--- DONE ---'));
## ------------------------
  return(list(remote_worker_conf=remote_worker_conf,rrs_result=rrs_result,train_jobs_counts=train_jobs_counts,score_jobs_counts=score_jobs_counts,perf_data=perf_data));

}

## =====================
## == LEVEL -1 FUNCTIONS
## =====================

## =====================
## == HELPER FUNCTIONS
## == FOR DESKTOP TESTING (CLI)
## == STEP 0 IN THE WHOLE PROCESS
## == This will do code coverage testing
## == EXAMPLE:
## == source('vox_cli_main.R'); VOX_SLEEP_ <<- 1; res <- vox_cli_test(1,1*1,0.01,'vox-training/ust-training-ver300L1.csv','ust');
## =====================

vox_cli_test <<- function ( this_worker_id, this_total_workers = 1, this_scan_prop = 100, this_train_path = 'vox-training/demo-training-ver20L1.csv', this_tenant_name = 'ust', this_keywords = 3, exclude_labels = c("i don't know") ) {

  VOX_TIME      <- proc.time()[3]; save(VOX_TIME,file='proctime.Rdata');
## ------------------------
## -- INDICATOR MATRIX AT LAST COLUMNS
  dataset       <- read.csv(this_train_path); ###!!!
  dataset       <- rbind(dataset,dataset[1,]);
  dataset       <- vox_module_convert(dataset,'labels','fuid', exclude_label = exclude_labels); ###!!!
  assign('dataset',dataset,.GlobalEnv); rm(list=setdiff(ls(envir=.GlobalEnv),c('dataset','VOX_ENVIR_TEST')),envir=.GlobalEnv); source('vox_cli_main.R'); rm(dataset);
## -- CUSTOM MODULE
## -- CONFIGURE WORKER
  dataset       <- vox_module_configure(dataset_in=dataset,setup_worker_id=this_worker_id,setup_total_workers=this_total_workers,setup_tenant_name=this_tenant_name); ###!!!
  assign('dataset',dataset,.GlobalEnv); rm(list=setdiff(ls(envir=.GlobalEnv),c('dataset')),envir=.GlobalEnv); source('vox_cli_main.R'); rm(dataset);
## -- CUSTOM MODULES
## -- PARAMTERIZE SVM
  dataset       <- vox_module_parametrize(dataset_in=dataset,setup_scan_prop=this_scan_prop,keywords=this_keywords); ###!!!
  assign('dataset',dataset,.GlobalEnv); rm(list=setdiff(ls(envir=.GlobalEnv),c('dataset','decompress_environment_')),envir=.GlobalEnv); rm(dataset);
## -- THIS GOES TO EXECUTE R MODEL
## -- RUN WORKERS (BES OR LOCALLY)
  decompress_environment_(dataset,'vox_module_spawn_');
  rm(list=setdiff(ls(envir=.GlobalEnv),c('dataset')),envir=.GlobalEnv); source('vox_cli_main.R');
## -- CUSTOM MODULES
## -- SCAN HYPER-PARAMETER SPACE
  dataset       <- vox_module_scan(dataset_in=dataset,total_sub_workers=this_total_workers,sub_worker_id=this_worker_id); ###!!! paralel loop
  dataset       <- vox_module_compare(scan_in_1=dataset,scan_in_2=dataset); ###!!! outside parallel look
  assign('dataset',dataset,.GlobalEnv); rm(list=setdiff(ls(envir=.GlobalEnv),c('dataset')),envir=.GlobalEnv); source('vox_cli_main.R'); rm(dataset);
## -- CREATE R MODEL
## -- CREATE FINAL R MODEL
  decompress_environment_(dataset,'vox_module_train_'); ### !!!
  
  
  
  rm(list=setdiff(ls(envir=.GlobalEnv),c('model','decompress_environment_')),envir=.GlobalEnv);
## -- CREATE R MODEL
## -- SCORE FINAL R MODEL
## -- WITHOUT LABEL
  dataset       <- read.csv(this_train_path,stringsAsFactors=FALSE)[1,c('fuid','text'),drop=FALSE]; dataset[1,'text'] <- ''; assign('dataset',dataset,.GlobalEnv);
  assign('VOX_MODULE_',attr(model,'VOX_MODULE_'),.GlobalEnv)$vox_module_score_(verbose=TRUE); save(model,file='modeltest.Rdata');
  rm(list=setdiff(ls(envir=.GlobalEnv),c('scores')),envir=.GlobalEnv); source('vox_cli_main.R');
  scores        <<- cbind(dataset,scores);
  performance   <- vox_module_evaluate(scores);
  view0         <<- vox_module_view(scores,0,'fuid');
  view1         <<- vox_module_view(scores,1,'fuid');
  view2         <<- vox_module_view(scores,2,'fuid');
  view3         <<- vox_module_view(scores,3,'fuid');
## -- CREATE R MODEL
## -- SCORE FINAL R MODEL
## -- WITH LABEL
  dataset       <- read.csv(this_train_path); assign('dataset',dataset,.GlobalEnv); load('modeltest.Rdata',envir=.GlobalEnv); unlink('modeltest.Rdata');
  assign('VOX_MODULE_',attr(model,'VOX_MODULE_'),.GlobalEnv)$vox_module_score_(verbose=TRUE);
  scores        <<- cbind(dataset,scores);
  rm(list=setdiff(ls(envir=.GlobalEnv),c('scores')),envir=.GlobalEnv); source('vox_cli_main.R');
  performance   <<- vox_module_evaluate(scores);
  view0         <<- vox_module_view(scores,0,'fuid');
  view1         <<- vox_module_view(scores,1,'fuid');
  view2         <<- vox_module_view(scores,2,'fuid');
  view3         <<- vox_module_view(scores,3,'fuid'); load('proctime.Rdata');
## -- TIME CHECK
  print(paste('Time elapsed for test',proc.time()[3]-VOX_TIME)); VOX_TEST_TIME <<- proc.time()[3]-VOX_TIME; VOX_TIME <<- proc.time()[3]; unlink('proctime.Rdata');
## ------------------------
  return(performance);

}

