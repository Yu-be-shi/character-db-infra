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

variable "ephemeral" {
  description = "使い捨て(up/down)環境か。true で destroy 容易な設定（削除保護無効・final snapshot 無し）"
  type        = bool
  default     = true
}
