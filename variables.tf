variable "token" {
  type      = string
  sensitive = true
}

variable "url" {
  type        = string
  description = "Provide OCM environment by setting a value to url"
  default     = "https://api.openshift.com"
}

variable "operator_role_prefix" {
  type    = string
  default = "tf-rosa"
}

variable "oidc_config_id" {
  type    = string
  default = ""
}

variable "cluster_name" {
  type    = string
  default = "rosa-hcp-tf"
}

variable "username" {
  description = "Admin username that will be created with the cluster"
  type        = string
  default     = "cluster-admin"
}

variable "openshift_version" {
  type    = string
  default = "4.15.0"
}

variable "tags" {
  description = "List of AWS resource tags to apply."
  type        = map(string)
  default = {
    "rosa_cluster" = "hcp"
  }
}

variable "cloud_region" {
  type    = string
  default = "eu-west-1"
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "vpc_cidr" {
  description = "Block of IP addresses for nodes"
  type        = string
  default     = "10.1.0.0/16"
}

variable "ocm_environment" {
  type    = string
  default = "production"
}

variable "path" {
  description = "(Optional) The arn path for the account/operator roles as well as their policies."
  type        = string
  default     = null
}
