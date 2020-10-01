/**
 * # 200compute
 */

# terraform block cannot be interpolated; sample provided as output of _main

terraform {
  required_version = ">= 0.12"

  backend "s3" {
    # this key must be unique for each layer!
    bucket  = "210330326423-build-state-bucket"
    key     = "terraform.development.200compute.tfstate"
    region  = "eu-west-1"
    encrypt = true
  }
}

# pinned provider versions

provider "aws" {
  version             = "~> 2.35"
  region              = var.region
  allowed_account_ids = [var.aws_account_id]
}

data "aws_ami" "amazon_windows_2016" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Windows_Server-2016-English-Full-Base-*"]
  }
}

module "vpc" {
  source   = "git@github.com:rackspace-infrastructure-automation/aws-terraform-vpc_basenetwork//?ref=v0.0.2"
  vpc_name = "${var.appname}-${var.environment}-BaseNetwork"

  custom_azs          = ["${var.region}a", "${var.region}b"]
  cidr_range          = "172.18.0.0/16"
  public_cidr_ranges  = ["172.18.0.0/22", "172.18.4.0/22"]
  private_cidr_ranges = ["172.18.32.0/21", "172.18.40.0/21"]

  build_nat_gateways   = true
  enable_dns_support   = true
  enable_dns_hostnames = true

  custom_tags = {
    Environment = "${var.environment}"
    Application = "${var.appname}-${var.environment}"
  }
}

module "security_group" {
  source        = "git@github.com:rackspace-infrastructure-automation/aws-terraform-security_group?ref=v0.0.4"
  resource_name = "${var.appname}-${var.environment}-SecurityGroup"
  vpc_id        = "${module.vpc.vpc_id}"
}

module "ec2_ar_windows_no_codedeploy" {
  source         = "git@github.com:rackspace-infrastructure-automation/aws-terraform-ec2_autorecovery?ref=v0.0.2"
  ec2_os         = "windows"
  instance_count = "${var.instance_count}"
  ec2_subnet     = "${element(module.vpc.private_subnets, 0)}"

  security_group_list = [
    "${module.security_group.private_rdp_security_group_id}",
  ]

  image_id                 = "${data.aws_ami.amazon_windows_2016.image_id}"
  key_pair                 = "${var.keyname}"
  instance_type            = "${var.instance_type}"
  resource_name            = "${var.appname}-${var.environment}"
  install_codedeploy_agent = false
  enable_ebs_optimization  = "False"
  tenancy                  = "default"
  backup_tag_value         = "False"
  detailed_monitoring      = "True"
  ssm_patching_group       = "${var.environment}"
  primary_ebs_volume_size  = "80"
  primary_ebs_volume_iops  = "0"
  primary_ebs_volume_type  = "gp2"
  environment              = "${var.environment}"

  instance_role_managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetRole",
    "arn:aws:iam::aws:policy/CloudWatchActionsEC2Access",
  ]

  perform_ssm_inventory_tag           = "True"
  cloudwatch_log_retention            = "30"
  ssm_association_refresh_rate        = "rate(1 day)"
  additional_ssm_bootstrap_step_count = "1"
  alarm_notification_topic            = ""
  disable_api_termination             = "True"
  t2_unlimited_mode                   = "standard"
  creation_policy_timeout             = "20m"
  cw_cpu_high_operator                = "GreaterThanThreshold"
  cw_cpu_high_threshold               = "90"
  cw_cpu_high_evaluations             = "15"
  cw_cpu_high_period                  = "60"

  additional_ssm_bootstrap_list = [
    {
      ssm_add_step = <<EOF
      {
        "action": "aws:runDocument",
        "inputs": {
          "documentPath": "arn:aws:ssm:${data.aws_region.current_region.name}:507897595701:document/Rack-Install_Datadog",
          "documentType": "SSMDocument"
        },
        "name": "InstallDataDog",
        "timeoutSeconds": 300
      }
EOF
    },
  ]

  additional_tags = {
    "Application" = "${var.appname}-${var.environment}"
    "Environment" = "${var.environment}"
  }
}