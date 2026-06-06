output "db_secret_arn" {
  description = "DB 認証情報の Secrets Manager ARN（api-infra の variables.tf に設定する）"
  value       = module.rds.secret_arn
}

output "rds_security_group_id" {
  description = "RDS セキュリティグループ ID（api-infra の variables.tf に設定する）"
  value       = module.rds.security_group_id
}

output "migrate_security_group_id" {
  description = "マイグレーション ECS タスクの SG ID（CI の MIGRATION_SG_ID 変数に設定する）"
  value       = module.migrate.security_group_id
}

output "migrate_ecr_repository_url" {
  description = "マイグレーションイメージの ECR リポジトリ URL（CI の push 先）"
  value       = module.migrate.ecr_repository_url
}
