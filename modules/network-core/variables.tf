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

variable "create_natgw" {
  type    = bool
  default = true
}

variable "gateway_endpoints" {
  type    = list(string)
  default = ["s3", "dynamodb"]
}

variable "interface_endpoints" {
  type    = list(string)
  default = ["logs", "ecr.api", "ecr.dkr"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
