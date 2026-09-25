terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "zuri-terraform-state-820765098114"
    key    = "prod/terraform.tfstate"
    region = "us-east-2"
  }
}

provider "aws" {
  region = var.region
}

module "networking" {
  source              = "../../modules/networking"
  env                 = var.env
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  az                  = var.az
  my_ip               = var.my_ip
}

module "iam" {
  source     = "../../modules/iam"
  env        = var.env
  region     = var.region
  account_id = var.account_id
}

module "compute" {
  source                = "../../modules/compute"
  env                   = var.env
  instance_type         = var.instance_type
  public_subnet_id      = module.networking.public_subnet_id
  app_sg_id             = module.networking.app_sg_id
  instance_profile_name = module.iam.instance_profile_name
  key_name              = var.key_name
}
