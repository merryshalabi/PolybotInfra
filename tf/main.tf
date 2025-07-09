terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.55"
    }
  }

  backend "s3" {
    bucket         = "merry-tf-state"
    key            = "polybot/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "merry-tf-locks"
  }

  required_version = ">= 1.7.0"
}

provider "aws" {
  region = var.aws_region
}

module "network" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "k8s-main-vpc"
  cidr = "10.0.0.0/16"

  azs            = var.availability_zones
  public_subnets = var.public_subnets

  enable_nat_gateway   = false
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Project = "Polybot"
  }
}

module "k8s_cluster" {
  source            = "./modules/k8s-cluster"
  vpc_id            = module.network.vpc_id
  subnet_ids        = module.network.public_subnets
  key_name          = var.key_name
  instance_type     = var.instance_type
  ami_id            = var.ami_id
  desired_capacity  = var.desired_capacity
  min_size          = var.min_size
  max_size          = var.max_size
  acm_cert_arn     = var.acm_cert_arn
  s3_bucket_name   = var.s3_bucket_name
  dynamodb_table_arn = var.dynamodb_table_arn
  sqs_queue_arn = var.sqs_queue_arn

}


