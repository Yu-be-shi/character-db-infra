variable "aws_region" {
  description = "AWS リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "RDS を配置するプライベートサブネット ID"
  type        = list(string)
}

variable "api_security_group_ids" {
  description = "DB アクセスを許可する API のセキュリティグループ ID（api-infra の outputs から取得）"
  type        = list(string)
}
