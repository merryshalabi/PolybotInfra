terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.55"
    }
  }
  backend "s3" {
    bucket = "merry-tf-state"
    key    = "tfstate.json"
    region = "eu-west-2"
    # optional: dynamodb_table = "<table-name>"
  }

  required_version = ">= 1.7.0"
}

provider "aws" {
  region  = var.region #"eu-west-2"
  profile = "default"  # change in case you want to work with another AWS account profile
}

resource "aws_instance" "polybot_app" {
  ami           = var.ami_id #"ami-044415bb13eee2391"
  instance_type = "t3.nano"

  tags = {
    Name      = "merry-terraform-practice-${var.env}"
    Terraform = "true"
    Env       = var.env
  }

}

module "polybot_service_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "merry-tf-vpc"
  cidr = "10.0.0.0/16"

  azs             = var.az
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = false

  tags = {
    Env         = var.env
  }
}
