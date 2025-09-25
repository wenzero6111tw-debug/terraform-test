locals {
  common_tags = merge({
    CostCenter = "platform",
    Owner      = "platform-engineering",
  }, var.tags)
}

resource "aws_organizations_organization" "this" {
  count       = var.org_enabled ? 1 : 0
  feature_set = "ALL"
}

resource "aws_s3_bucket" "audit_logs" {
  bucket        = "${replace(lower("<ORG_NAME>"), " ", "-")}-audit-logs"
  force_destroy = false
  tags          = local.common_tags
}

resource "aws_kms_key" "logs" {
  description             = "KMS for audit logs"
  enable_key_rotation     = true
  multi_region            = var.kms_multi_region
  deletion_window_in_days = 30
  tags                    = local.common_tags
}

resource "aws_cloudtrail" "org" {
  name                          = "org-trail"
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  s3_bucket_name                = aws_s3_bucket.audit_logs.bucket
  kms_key_id                    = aws_kms_key.logs.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }

    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda"]
    }
  }

  tags = local.common_tags
}

resource "aws_guardduty_detector" "this" {
  enable = true
}

resource "aws_securityhub_account" "this" {}

resource "aws_budgets_budget" "monthly" {
  name         = "platform-monthly"
  budget_type  = "COST"
  limit_amount = var.budget_monthly_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
}
