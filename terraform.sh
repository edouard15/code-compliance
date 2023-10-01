#!/bin/bash

#set -x

export TF_LOG="DEBUG" #export is used in bash to set env. var.
export TF_LOG_PATH="./terraform.log" #give the path for where the debug will be stored

ENV=prod
TF_PLAN="${ENV}".tfplan #[]is to check condition in bash

#wget https://github.com/tfsec/tfsec/releases/download/v1.28.1/tfsec-darwin-amd64
#chmod +x tfsec-darwin-amd64
#cp tfsec-darwin-amd64 /usr/local/bin/tfsec
#rm tfsec-darwin-amd64

[ -d .terraform ] && rm -rf .terraform
rm -f *.tfplan #rm whatever exist at line 9 before proceed
sleep 2 #pause for 2 second


terraform fmt -recursive #go through all directory and fmt
terraform init
terraform validate
terraform plan -out=${TF_PLAN}

#tfsec .
terraform show -json ${TF_PLAN} | jq '.'| > ${TF_PLAN}.json # terraform show return a json format
checkov -f ${TF_PLAN}.json #checkov will read this file

if [ "$?" -eq "0" ]
then
  echo "your cofiguration is valid"
else
  echo "your code needs some work"
  exit 1
fi

terraform plan -out=${TF_PLAN}

if [ ! -f "{TF_PLAN}" ] #if TF_PLAN not exist 
then
  echo "***The plan does not exit. Exiting"
  exit 1
fi