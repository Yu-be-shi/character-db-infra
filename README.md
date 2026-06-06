# db-infra

character-db（PostgreSQL）専用のインフラリポジトリ。
DBのプロビジョニング・セキュリティ境界・マイグレーション本番適用を管理する。

## 責務

- AWS RDS PostgreSQL のプロビジョニング（Terraform）
- DB 認証情報の Secrets Manager 管理
- マイグレーションの本番適用 CI（GitHub Actions）
- ローカル・CI 用の DB 単体起動（Docker Compose）

## リポジトリレイアウト前提

```
workspace/
├── db/        # character-db（DDL/マイグレーション）
└── db-infra/  # このリポジトリ
```

## 環境別の使い方

### ローカル / CI（DB 単体起動）

```bash
docker compose up
```

### 本番（Terraform）

```bash
cd terraform/environments/prod

# 初回のみ
terraform init
cp prod.tfvars.example prod.tfvars  # 値を編集する

terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

## セキュリティ境界

- RDS はプライベートサブネットのみに配置し、インターネットからの直接アクセスを遮断
- DB 認証情報（パスワード、DSN）は Secrets Manager で管理。コードや環境変数ファイルには書かない
- DB へのアクセスは `allowed_security_group_ids` に登録された API の SG のみに限定

## api-infra との連携

`terraform output` で得られる以下の値を api-infra の variables に渡す:

| db-infra の output | api-infra の variable |
|---|---|
| `db_secret_arn` | `db_secret_arn` |
| `rds_security_group_id` | `rds_security_group_id` |
