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
      source  = "terraform-redhat/rhcs"
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
    role_arn         = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.account_role_prefix}-hcp-rosa-installer-role",
    support_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.account_role_prefix}-hcp-rosa-support-role",
    instance_iam_roles = {

      worker_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.account_role_prefix}-hcp-rosa-worker-role"
    },

    operator_role_prefix = var.operator_role_prefix,
    oidc_config_id       = module.oidc_config.id
  }

  name   = var.cluster_name
  region = var.cloud_region

  account_id = data.aws_caller_identity.current.account_id
  version    = var.openshift_version

  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
}

# Create managed OIDC config
module "oidc_config" {
  token                = var.token
  url                  = var.url
  source               = "./oidc_provider"
  managed              = true
  operator_role_prefix = var.operator_role_prefix
  account_role_prefix  = var.account_role_prefix
  tags                 = var.tags
  path                 = var.path
}

module "create_account_roles" {
  source  = "terraform-redhat/rosa-sts/aws"
  version = ">=0.0.15"

  create_account_roles = true

  account_role_prefix    = var.account_role_prefix
  ocm_environment        = var.ocm_environment
  rosa_openshift_version = join(".", slice(split(".", local.version), 0, 2))
  account_role_policies  = data.rhcs_policies.all_policies.account_role_policies
  operator_role_policies = data.rhcs_policies.all_policies.operator_role_policies
  all_versions           = data.rhcs_versions.all
  path                   = var.path
  tags                   = var.tags
}


resource "rhcs_cluster_rosa_hcp" "rosa_hcp_cluster" {
  name                   = local.name
  sts                    = local.sts_roles
  cloud_region           = local.region
  aws_account_id         = local.account_id
  aws_billing_account_id = local.account_id

  availability_zones = local.azs
  multi_az           = var.multi_az

  version              = local.version
  aws_subnet_ids       = join(",", concat(module.vpc.public_subnets, module.vpc.private_subnets))
  worker_disk_size     = 300
  compute_machine_type = "m5.xlarge"
  # autoscaling_enabled         = true
  # min_replicas                = 3
  # max_replicas                = 6
  replicas                    = 3
  ec2_metadata_http_tokens    = "required"
  default_mp_labels           = { "MachinePool" = "core" }
  disable_workload_monitoring = true

  properties = {
    rosa_creator_arn = data.aws_caller_identity.current.arn
  }

  admin_credentials = {
    username = var.username,
    password = data.aws_secretsmanager_secret_version.admin_password_version.secret_string
  }

  wait_for_create_complete = true
  destroy_timeout          = 60

  depends_on = [module.create_account_roles]
}

resource "rhcs_cluster_wait" "rosa_cluster" {
  cluster = rhcs_cluster_rosa_hcp.rosa_hcp_cluster.id
  # timeout in minutes
  timeout = 60
}

data "rhcs_rosa_operator_roles" "operator_roles" {
  operator_role_prefix = var.operator_role_prefix
  account_role_prefix  = var.account_role_prefix
}

module "operator_roles" {
  source  = "terraform-redhat/rosa-sts/aws"
  version = ">=0.0.15"

  create_operator_roles = true
  create_oidc_provider  = false

  cluster_id                  = rhcs_cluster_rosa_hcp.rosa_hcp_cluster.id
  rh_oidc_provider_thumbprint = rhcs_cluster_rosa_hcp.rosa_hcp_cluster.sts.thumbprint
  rh_oidc_provider_url        = rhcs_cluster_rosa_hcp.rosa_hcp_cluster.sts.oidc_endpoint_url
  operator_roles_properties   = data.rhcs_rosa_operator_roles.operator_roles.operator_iam_roles
  tags                        = var.tags
}

resource "rhcs_machine_pool" "mp1_machine_pool" {
  cluster             = rhcs_cluster_rosa_hcp.rosa_hcp_cluster.id
  name                = "mp1"
  machine_type        = "r6i.2xlarge"
  disk_size           = 300
  autoscaling_enabled = true
  min_replicas        = 3
  max_replicas        = 9
  labels              = { "MachinePool" = "mp1" }
  # taints = [{
  # key           = "dedicated",
  # value         = "mp1",
  # schedule_type = "NoSchedule"
  # }]

  depends_on = [rhcs_cluster_rosa_hcp.rosa_hcp_cluster]
}


#---------------------------------------------------------------
# Cluster Admin credentials resources
#---------------------------------------------------------------
data "aws_secretsmanager_secret_version" "admin_password_version" {
  secret_id  = aws_secretsmanager_secret.rosa_hcp.id
  depends_on = [aws_secretsmanager_secret_version.rosa_hcp]
}

resource "random_password" "rosa_hcp" {
  length           = 16
  special          = true
  override_special = "@_"
}

#tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "rosa_hcp" {
  name                    = local.name
  recovery_window_in_days = 0 # Set to zero for this example to force delete during Terraform destroy
}

resource "aws_secretsmanager_secret_version" "rosa_hcp" {
  secret_id     = aws_secretsmanager_secret.rosa_hcp.id
  secret_string = random_password.rosa_hcp.result
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
