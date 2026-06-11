terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ── ECR ───────────────────────────────────────────────────────────────────────

resource "aws_ecr_repository" "migrate" {
  name = var.name
  # SHA タグ運用のため IMMUTABLE（api 側 ECR と揃える）。CI は push 前にタグ存在を確認する。
  image_tag_mutability = "IMMUTABLE"
  # ephemeral（daily up/down）ではイメージが残っていても destroy を通す。
  # これが無いと up 後の down が RepositoryNotEmptyException で失敗する。
  force_delete = var.ephemeral

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

# ── IAM ───────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "migrate_execution" {
  name = "${var.name}-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "migrate_execution" {
  role       = aws_iam_role.migrate_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "migrate_secrets" {
  name = "secrets-access"
  role = aws_iam_role.migrate_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.db_secret_arn]
    }]
  })
}

# ── ネットワーク ────────────────────────────────────────────────────────────────

# マイグレーションタスク専用 SG
resource "aws_security_group" "migrate" {
  name        = "${var.name}-task"
  description = "Migration ECS task — egress only"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# RDS SG にマイグレーション SG からの ingress を追加
resource "aws_security_group_rule" "rds_allow_migrate" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.migrate.id
  security_group_id        = var.rds_security_group_id
  description              = "Allow migration ECS task to access RDS"
}

# ── ログ ───────────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "migrate" {
  name              = "/ecs/${var.name}"
  retention_in_days = 14
  tags              = var.tags
}

# ── ECS タスク定義 ─────────────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "migrate" {
  family                   = var.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.migrate_execution.arn

  container_definitions = jsonencode([{
    name  = "migrate"
    image = "${aws_ecr_repository.migrate.repository_url}:${var.image_tag}"

    # ENTRYPOINT は Dockerfile.migrate に設定済み（migrate-entrypoint.sh）。
    # ECS の exec 形式 command はシェルを介さず $(VAR) を展開しないため、
    # 接続先は command 引数ではなく環境変数 DB_DSN で渡し、entrypoint 側が
    # フォールバックとして読む。atlas は URL 形式しか受け付けないため
    # secret の url キー（postgres://...）を使う。
    command = []

    secrets = [
      { name = "DB_DSN", valueFrom = "${var.db_secret_arn}:url::" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.migrate.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = var.tags
}
