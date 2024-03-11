#
# Copyright (c) 2022 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.20.0"
    }
    rhcs = {
      version = ">= 1.5.1"
      source  = "terraform.local/local/rhcs"
    }
  }
}

provider "rhcs" {
  token = var.token
  url   = var.url
}

provider "aws" {
  region = local.region
}

data "rhcs_policies" "all_policies" {}
data "rhcs_versions" "all" {}
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  path = coalesce(var.path, "/")

  sts_roles = {
    role_arn         = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ManagedOpenShift-HCP-ROSA-Installer-Role",
    support_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ManagedOpenShift-HCP-ROSA-Support-Role",
    instance_iam_roles = {

      worker_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ManagedOpenShift-HCP-ROSA-Worker-Role"
    },

    operator_role_prefix = var.operator_role_prefix,
    oidc_config_id       = var.oidc_config_id
  }

  name   = var.cluster_name
  region = var.cloud_region

  account_id = data.aws_caller_identity.current.account_id
  version    = var.openshift_version

  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 1)
}

resource "rhcs_cluster_rosa_hcp" "rosa_hcp_cluster" {
  name                   = local.name
  sts                    = local.sts_roles
  cloud_region           = local.region
  aws_account_id         = local.account_id
  aws_billing_account_id = local.account_id

  availability_zones = local.azs

  version = local.version
  aws_subnet_ids       = concat(list(module.vpc.public_subnets), list(module.vpc.private_subnets))
  machine_cidr         = local.vpc_cidr
  compute_machine_type = "m5.xlarge"
  replicas                    = 3

  properties = {
    rosa_creator_arn = data.aws_caller_identity.current.arn
  }

  wait_for_create_complete = true
  destroy_timeout          = 60

}

resource "rhcs_cluster_wait" "rosa_cluster" {
  cluster = rhcs_cluster_rosa_hcp.rosa_hcp_cluster.id
  # timeout in minutes
  timeout = 60
}


module "vpc" {
 source  = "terraform-aws-modules/vpc/aws"
 version = "~> 5.0"
 
 name = local.name
 cidr = local.vpc_cidr
 
 azs             = local.azs
 private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
 public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]
 
 enable_nat_gateway      = true
 single_nat_gateway      = var.multi_az
 enable_dns_hostnames    = true
 enable_dns_support      = true
 map_public_ip_on_launch = true
 
 public_subnet_tags = {
 "kubernetes.io/role/elb" = 1
 }

 private_subnet_tags = {
 "kubernetes.io/role/internal-elb" = 1
 }
 
 tags = var.tags
 }
