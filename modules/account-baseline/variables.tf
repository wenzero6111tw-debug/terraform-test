variable "org_enabled" {
  type    = bool
  default = true
}

variable "organization_units" {
  description = "List of OU names to create or reference."
  type        = list(string)
  default     = ["Sandbox", "Workloads", "Security", "Shared"]
}

variable "audit_account_id" {
  type = string
}

variable "security_account_id" {
  type = string
}

variable "cloudtrail_retention_days" {
  type    = number
  default = 365
}

variable "config_recorder" {
  type    = bool
  default = true
}

variable "kms_multi_region" {
  type    = bool
  default = true
}

variable "budget_monthly_limit" {
  type    = number
  default = 1000
}

variable "tags" {
  type    = map(string)
  default = {}
}
