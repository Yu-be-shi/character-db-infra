variable "name" {
  description = "リソース名のプレフィックス"
  type        = string
  default     = "character-db-migrate"
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  description = "マイグレーションタスクを起動するプライベートサブネット"
  type        = list(string)
}

variable "db_secret_arn" {
  description = "DB 認証情報の Secrets Manager ARN（rds モジュールの output）"
  type        = string
}

variable "rds_security_group_id" {
  description = "RDS のセキュリティグループ ID（マイグレーション SG の ingress 許可に使用）"
  type        = string
}

variable "image_tag" {
  description = "ECR に push されたマイグレーションイメージのタグ"
  type        = string
  default     = "latest"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "ephemeral" {
  description = "使い捨て運用（daily up/down）。ECR の force_delete に連動する"
  type        = bool
  default     = false
}
