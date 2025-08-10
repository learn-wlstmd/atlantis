data "aws_caller_identity" "current" {}

provider "aws" {
  region = "ap-northeast-2"
  alias  = "ap-northeast-2"
}
