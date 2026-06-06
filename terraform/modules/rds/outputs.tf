output "instance_address" {
  description = "RDS エンドポイント"
  value       = aws_db_instance.main.address
}

output "secret_arn" {
  description = "DB 認証情報の Secrets Manager ARN（API側のタスク定義で参照する）"
  value       = aws_secretsmanager_secret.db.arn
}

output "security_group_id" {
  description = "RDS セキュリティグループ ID"
  value       = aws_security_group.rds.id
}
