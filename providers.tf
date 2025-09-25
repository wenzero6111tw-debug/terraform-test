provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  description = "Default AWS region for root-level provider (overridden per stack)."
  default     = "ap-northeast-1"
}
