variable "app_name" {
  description = "The name of the application, e.g. Magento, Wordpress, CustomerName, etc."
  type        = string
}

variable "aws_account_id" {
  description = "The account ID you are building into."
  type        = string
}

variable "environment" {
  description = "The name of the environment, e.g. Production, Development, etc."
  type        = string
}


variable "region" {
  default = "eu-west-1"
}


variable "name" {
  default = "TestBuild"
}

variable "keyname" {
  default = "CircleCI"
}

variable "appname" {
  default = "autorecovery"
}

############
#   EC2    #
############

variable "instance_count" {
  default = "1"
}

variable "instance_type" {
  default = "t2.small"
}