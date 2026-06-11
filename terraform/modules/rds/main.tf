terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "db" {
  name = "${var.identifier}/db-credentials"
  # ephemeral（daily up/down）では即時削除にする。7 日の削除待ちを残すと、
  # 翌日の up で同名 secret の再作成が "scheduled for deletion" エラーになる。
  recovery_window_in_days = var.ephemeral ? 0 : 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
    # api/ の DB_DSN として直接使用できる libpq key=value 形式
    dsn = "host=${aws_db_instance.main.address} user=${var.db_username} password=${random_password.db.result} dbname=${var.db_name} port=${aws_db_instance.main.port} sslmode=require TimeZone=UTC"
    # atlas（migrate タスク）用の URL 形式。atlas の --url は URL 形式しか
    # 受け付けないため key=value 形式の dsn とは別に持つ。
    # random_password は special=false（英数字のみ）なので URL エンコード不要。
    url = "postgres://${var.db_username}:${random_password.db.result}@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${var.db_name}?sslmode=require"
  })
}

resource "aws_db_subnet_group" "main" {
  name       = var.identifier
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "rds" {
  name        = "${var.identifier}-rds"
  description = "Allow PostgreSQL access from API"
  vpc_id      = var.vpc_id

  # egress は定義しない: SG はステートフルで、許可した ingress への応答は自動で
  # 通る。RDS 自身から外向きに張る接続は無いため、全開放 egress は不要。

  tags = var.tags
}

# inline ingress ではなく独立ルールで定義する。
# allowed_security_group_ids が空（初回 up：API SG がまだ無い段階）でも
# 「ソース無し ingress」にならず apply が成立する。
# ※ migrate 用ルール（aws_security_group_rule.rds_allow_migrate）は旧方式
#   （aws_security_group_rule）のまま。動作に問題は無いが方式は揃っていない。
resource "aws_vpc_security_group_ingress_rule" "rds_from_api" {
  for_each = toset(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.rds.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value
  description                  = "Allow API to access RDS"

  tags = var.tags
}

resource "aws_db_instance" "main" {
  identifier        = var.identifier
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # ephemeral（使い捨て）構成では destroy を妨げない設定にする。
  # データは永続させない方針のため、final snapshot も取らず削除保護も無効。
  backup_retention_period   = var.ephemeral ? 0 : 7
  skip_final_snapshot       = var.ephemeral
  final_snapshot_identifier = var.ephemeral ? null : "${var.identifier}-final"
  deletion_protection       = !var.ephemeral

  tags = var.tags
}
