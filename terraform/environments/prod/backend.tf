terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "db-infra/prod/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
