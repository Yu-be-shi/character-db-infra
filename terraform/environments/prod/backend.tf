# S3 backend（部分設定）。bucket は環境依存のためコミットせず、init 時に注入する:
#   terraform init -backend-config="bucket=<state バケット名>"
# CI では Repository Variable `TF_STATE_BUCKET` から渡す。
terraform {
  backend "s3" {
    key            = "db-infra/prod/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
