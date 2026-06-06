output "security_group_id" {
  description = "マイグレーションタスクのセキュリティグループ ID"
  value       = aws_security_group.migrate.id
}

output "task_definition_arn" {
  description = "マイグレーション ECS タスク定義 ARN"
  value       = aws_ecs_task_definition.migrate.arn
}

output "ecr_repository_url" {
  description = "マイグレーションイメージの ECR リポジトリ URL"
  value       = aws_ecr_repository.migrate.repository_url
}
