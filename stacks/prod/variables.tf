variable "audit_account_id" {
  type        = string
  description = "Audit account ID"
}

variable "security_account_id" {
  type        = string
  description = "Security tooling account ID"
}

variable "budget_monthly_limit" {
  type        = number
  default     = 2000
  description = "Monthly budget threshold in USD"
}

variable "cloudtrail_retention_days" {
  type    = number
  default = 365
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}
