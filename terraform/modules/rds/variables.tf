variable "identifier" {
  description = "RDS インスタンス識別子（リソース名のプレフィックスになる）"
  type        = string
}

variable "db_name" {
  description = "データベース名"
  type        = string
  default     = "characters"
}

variable "db_username" {
  description = "DBマスターユーザー名"
  type        = string
  default     = "app"
}

variable "instance_class" {
  description = "RDS インスタンスクラス"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "ストレージ容量 (GB)"
  type        = number
  default     = 20
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "RDS を配置するプライベートサブネット ID のリスト"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "DB へのアクセスを許可するセキュリティグループ ID のリスト（APIのSGを指定）"
  type        = list(string)
}

variable "ephemeral" {
  description = "使い捨て(up/down)環境か。true なら deletion_protection 無効・final snapshot 無し・backup 無しで destroy を妨げない"
  type        = bool
  default     = false
}

variable "tags" {
  description = "全リソースに付与するタグ"
  type        = map(string)
  default     = {}
}
