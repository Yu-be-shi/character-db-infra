provider "aws" {
  region = var.aws_region
}

module "rds" {
  source = "../../modules/rds"

  identifier                 = "character-db-prod"
  db_name                    = "characters"
  db_username                = "app"
  instance_class             = "db.t3.micro"
  allocated_storage          = 20
  vpc_id                     = var.vpc_id
  private_subnet_ids         = var.private_subnet_ids
  allowed_security_group_ids = var.api_security_group_ids
  ephemeral                  = var.ephemeral

  tags = local.tags
}

module "migrate" {
  source = "../../modules/migrate"

  aws_region            = var.aws_region
  vpc_id                = var.vpc_id
  private_subnet_ids    = var.private_subnet_ids
  db_secret_arn         = module.rds.secret_arn
  rds_security_group_id = module.rds.security_group_id
  image_tag             = var.image_tag

  tags = local.tags
}

locals {
  tags = {
    Environment = "prod"
    Project     = "character-system"
    ManagedBy   = "terraform"
  }
}
