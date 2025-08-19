# Cloud Archive

AWS-based infrastructure hosting static website designed to upload, store and download files in S3 Glacier. The purpose is to have simple tool to archive files like photos you don't access frequently but you need cheap option to store them somewhere.

> [!CAUTION]
> This Terraform code creates public-facing website without any access restrictions. Deploy it with caution!

## Infrastructure

The cloud infrastructure is basically made up of two components at this moment:
- AWS S3 bucket hosting static website and storing files
- AWS Lambda function acting as backend service to upload files

## Pre-requisites

- An AWS account
- Set of AWS credentials

## How to build it

```terraform
terraform init
terraform plan
terraform apply -auto-approve
```

## How to destroy it

```terraform
terraform destroy -auto-approve
```

## Future development

- Authorization layer (e.g. AWS Cognito) to allow only authenticated users to make requests
- Photo gallery where you can browse uploaded files in UI
- Enhanced security for AWS Lambda function