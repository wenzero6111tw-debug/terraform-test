terraform {
  backend "s3" {
    bucket         = "<ORG_NAME>-tfstate"
    key            = "<STACK_NAME>/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "<ORG_NAME>-tf-lock"
    encrypt        = true
  }
}
