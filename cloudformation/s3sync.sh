#!/usr/bin/env bash

if [[ -z "$1" ]]; then
  echo "You must supply a bucket name"
  exit 1
else
  is_bucket=$(aws s3 ls | grep "$1")
  if [[ -z "$is_bucket" ]] && [[ $? -eq 0 ]]; then
    echo "Bucket $1 does not exist, make the bucket first."
    exit 1
  fi
fi


aws s3 sync . s3://$1/cfn/
