# db-infra

character-db（PostgreSQL）専用のインフラリポジトリ。
DBのプロビジョニング・セキュリティ境界・マイグレーション本番適用を管理する。

## 責務

- AWS RDS PostgreSQL のプロビジョニング（Terraform `modules/rds`）
- DB 認証情報の Secrets Manager 管理
- **マイグレーション実行基盤**（Terraform `modules/migrate`: 専用 ECR + ECS タスク定義 + IAM/SG）
- マイグレーションの検証 CI / 手動再適用（GitHub Actions `migrate.yml`）
- STG（自宅サーバー）への自動デプロイ（`deploy-stg.yml`）
- ローカル・CI 用の DB スタック起動（Docker Compose。外部ネットワーク `character-db-net` を作成）

> **クロスリポジトリの前提**: migrate ECS タスクは **api-infra が作成する ECS クラスター上で
> 実行**される（クラスターを自前で持たない）。API スタックが down している間は
> `migrate.yml` の手動実行（run-migration）は使えない。通常のスキーマ適用は
> `prod-switch.yml`（api-infra）の up シーケンスに組み込まれている。

## リポジトリレイアウト前提

各 docker-compose / CI は、メタリポジトリ `character-system/` 配下に sibling として
clone されていることを前提にする（compose の build context は `../character-db`）:

```
character-system/
├── character-db/        # DDL/マイグレーション（スキーマの唯一の正）
├── character-db-infra/  # このリポジトリ
├── apis/character-api-go(-infra)/
└── applications/character-application-nextjs/
```

## 環境別の使い方

### ローカル / CI（DB スタック起動）

```bash
cp .env.example .env   # 省略可（compose にデフォルト値あり）
docker compose up -d   # PostgreSQL 起動 + character-db-migrate（atlas → views → seeds）

# マイグレーションだけ再実行（migrations/views/seeds の編集を反映）
docker compose run --rm --build character-db-migrate
```

デバッグ用のホスト公開（5432）は**ループバック限定**（LAN/外部に晒さない）。

### 本番（Terraform）

S3 backend は **bucket を持たない部分設定**（環境依存の値をコミットしないため）。
init 時に必ず注入する:

```bash
cd terraform/environments/prod

# 初回のみ（state バケットと DynamoDB ロックテーブル terraform-state-lock は事前作成しておく）
terraform init -backend-config="bucket=<state バケット名>"

# 変数は TF_VAR_* で渡す（CI と同じ方式。prod.tfvars はコミットしない）
export TF_VAR_vpc_id=vpc-xxxx
export TF_VAR_private_subnet_ids='["subnet-a","subnet-b"]'
export TF_VAR_api_security_group_ids='[]'
terraform plan
terraform apply
```

> **ネットワーク前提**: ECS migrate タスクはプライベートサブネット（public IP なし）で
> 動くため、ECR / Secrets Manager / CloudWatch Logs への到達経路（NAT Gateway もしくは
> VPC エンドポイント）が既存 VPC 側に必要。

通常の本番 up/down は api-infra の `prod-switch.yml`（workflow_dispatch）が
「DB → API → DB 再適用」の3段で行う。このリポジトリ単体で apply するのは検証時のみ。

## CI（GitHub Actions）が要求する設定

| 種別 | 名前 | 用途 |
|---|---|---|
| Secret | `GH_PAT` | private な character-db の cross-checkout（repo スコープ） |
| Secret | `AWS_ROLE_ARN` | OIDC で Assume する IAM ロール（plan / run-migration） |
| Secret | `TF_VAR_VPC_ID` / `TF_VAR_PRIVATE_SUBNET_IDS` / `TF_VAR_API_SG_IDS` | Terraform 変数 |
| Variable | `TF_STATE_BUCKET` | S3 backend のバケット名（`terraform init -backend-config`） |
| Variable | `ECS_CLUSTER` | run-migration が使う ECS クラスター名（api-infra が作成） |
| Variable | `STG_ROOT` | STG 自宅サーバーのメタリポジトリ配置先（既定 `~/character-system`） |

ワークフロー:

- `migrate.yml` … PR: マイグレーション SQL 検証（atlas validate / squawk / 本番同等イメージで適用テスト）+ Terraform plan。workflow_dispatch: 本番 RDS への手動再適用（character-db@main を build → ECR push → タスク定義更新 → run-task）
- `deploy-stg.yml` … develop push: STG（self-hosted runner `character-stg`）で `git pull` → PostgreSQL 起動 → migrate を分離実行（終了コードを伝播）

## セキュリティ境界

- RDS はプライベートサブネットのみに配置し、インターネットからの直接アクセスを遮断
- DB 認証情報（パスワード、DSN）は Secrets Manager で管理。コードや環境変数ファイルには書かない
- DB へのアクセスは `allowed_security_group_ids` に登録された API の SG と migrate タスクの SG のみに限定
- `ephemeral = true`（既定）では削除保護なし・final snapshot なし・secret 即時削除・ECR force_delete
  （**データは永続しない**。up 時に seeds を再投入する運用）

## api-infra との連携

`terraform output` で得られる以下の値を api-infra の variables に渡す:

| db-infra の output | api-infra の variable |
|---|---|
| `db_secret_arn` | `db_secret_arn` |
| `rds_security_group_id` | `rds_security_group_id` |

逆に migrate タスクの実行先クラスターは api-infra が作る（上記クロスリポジトリ前提を参照）。
