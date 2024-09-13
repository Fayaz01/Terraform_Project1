terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.65.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
terraform {
  backend "s3" {
    bucket = "backend-remote-dynamo66"
    dynamodb_table = "backend_table"
    key    = "global/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}