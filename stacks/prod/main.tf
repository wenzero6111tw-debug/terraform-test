terraform {
  required_version = ">= 1.6.0"
}

locals {
  common_tags = {
    Environment = "prod"
    Owner       = "platform"
  }
}

module "account_baseline" {
  source = "../../modules/account-baseline"

  audit_account_id        = var.audit_account_id
  security_account_id     = var.security_account_id
  budget_monthly_limit    = var.budget_monthly_limit
  cloudtrail_retention_days = var.cloudtrail_retention_days
  tags                    = local.common_tags
}

module "network_core" {
  source = "../../modules/network-core"

  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  create_natgw         = true
  tags                 = local.common_tags
}

module "iam_sso" {
  source = "../../modules/iam-sso"

  permission_boundary_policy_json = file("../../policies/iam/permission-boundary.json")
  tags                            = local.common_tags
}
