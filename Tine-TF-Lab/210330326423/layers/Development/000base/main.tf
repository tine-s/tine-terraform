/**
 * # 000base
 */

# terraform block cannot be interpolated; sample provided as output of _main

terraform {
  required_version = ">= 0.12"

  backend "s3" {
    # this key must be unique for each layer!
    bucket  = "210330326423-build-state-bucket"
    key     = "terraform.development.000base.tfstate"
    region  = "eu-west-1"
    encrypt = "true"
  }
}

# pinned provider versions

provider "aws" {
  version             = "~> 2.35"
  region              = var.region
  allowed_account_ids = [var.aws_account_id]
}

provider "random" {
  version = "~> 2.0"
}

provider "template" {
  version = "~> 2.0"
}

data "terraform_remote_state" "main_state" {
  backend = "local"

  config = {
    path = "../../_main/terraform.tfstate"
  }
}

locals {
  tags = {
    Environment     = var.environment
    ServiceProvider = "Rackspace"
  }
}

######## Base Network setup with VPC Endpoints ########

module "base_network" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-vpc_basenetwork//?ref=v0.12.1"

  az_count            = length(var.private_cidr_ranges)
  cidr_range          = var.cidr_range
  environment         = var.environment
  name                = "${var.environment}-${var.app_name}-VPC"
  private_cidr_ranges = var.private_cidr_ranges
  public_cidr_ranges  = var.public_cidr_ranges
  tags                = local.tags
}

module "vpc_endpoint" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-vpc_endpoint//?ref=v0.12.0"

  dynamo_db_endpoint_enable = true
  environment               = var.environment

  route_tables = concat(
    module.base_network.private_route_tables,
    module.base_network.public_route_tables,
  )

  s3_endpoint_enable = true
  tags               = local.tags
  vpc_id             = module.base_network.vpc_id
}

######## Route53 Internal Zone creation ########

module "internal_zone" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-route53_internal_zone//?ref=v0.12.0"

  environment = "${var.environment}"
  name        = "${lower(var.environment)}.local"
  tags        = local.tags
  vpc_id      = module.base_network.vpc_id
}

######## SNS Topic creation ########

module "sns_topic" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-sns//?ref=v0.12.0"

  name = "${var.environment}-${var.app_name}-SNS-Topic"
}

######## Service Role Creation ########

module "ssm_service_roles" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-iam_resources//modules/ssm_service_roles?ref=v0.12.0"

  create_automation_role         = true
  create_maintenance_window_role = true
}
