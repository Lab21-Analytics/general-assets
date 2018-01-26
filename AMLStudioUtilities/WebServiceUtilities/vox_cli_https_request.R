## =====================
## == LEVEL 3 FUNCTIONS (we don't need the HTTP <-> HTTPS wrapper here so we are relacing this with the function below)
## =====================

send_request_ <<- function ( http_url, this_body, api_url, command, authorization_header, type, params, this_header ) {

  result                <- NULL;
## ------------------------
## -- All the constants are just not to overload AML platform - we don't need them locally
  VOX_SLEEP_            <<- 0;
  VOX_POST_LIMIT_       <<- 4*1024*1024;
  VOX_GET_LIMIT_        <<- 4*1024*1024;
## -- THIS should be possible on AML but it's not so we can do it only locally 
  body                  <- basicTextGatherer();
  header                <- basicTextGatherer();
  if ( nchar(this_header) > 1 ) {
    http_header         <- as.character(c(paste('Authorization:',authorization_header),paste('Content-Type:','application/json'),this_header));
  } else {
    http_header         <- as.character(c(paste('Authorization:',authorization_header),paste('Content-Type:','application/json')));
  }
  status                <- curlPerform(url=paste(api_url,command,params,sep=''),writefunction=body$update,headerfunction=header$update,verbose=FALSE,postfields=this_body,httpheader=http_header,customrequest=type);
  body                  <- body$value();
  header                <- header$value();
  result                <- list(header=header,body=body);
## ------------------------
  return(result);

}
