terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.58"
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
  name                    = "${var.identifier}/db-credentials"
  recovery_window_in_days = 7
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
    # api/ の DB_DSN として直接使用できる形式
    dsn = "host=${aws_db_instance.main.address} user=${var.db_username} password=${random_password.db.result} dbname=${var.db_name} port=${aws_db_instance.main.port} sslmode=require TimeZone=UTC"
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

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
