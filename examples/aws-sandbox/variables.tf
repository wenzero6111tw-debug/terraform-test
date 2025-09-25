variable "region" {
  type    = string
  default = "ap-northeast-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.30.0.0/24", "10.30.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.30.10.0/24", "10.30.11.0/24"]
}

variable "budget_usd" {
  type    = number
  default = 5
}

variable "enable_config" {
  type    = bool
  default = false
}

variable "ttl_hours" {
  type    = number
  default = 24
}

variable "tags" {
  type    = map(string)
  default = {
    Env     = "dev"
    Project = "aws-sandbox"
  }
}
