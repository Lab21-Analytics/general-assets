 
DeployADFSolution
==================
This file requires the:
    - name of a configuration file located in the TEIADF project
    - name of the Azure Data Factory you want to build and deploy to
    - user credentials to access the Azure subscription

Once the program has the required information, it will first delete Pipelines, Datasets, and LinkedServices if they exist (in this order).
Then it will build and deploy the components in the order of LinkedServices, Datasets, and Pipelines. A yes/no dialog box may appear if you are deleting 
or overwriting an existing ADF component. Components that have multiple existing dependancies will not allow deletion.

