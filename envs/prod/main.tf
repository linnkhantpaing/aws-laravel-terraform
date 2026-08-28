locals {
  secret_path = "myapp/prod"
}

# Dependency order: network -> security -> storage -> secrets -> database -> compute -> cicd

module "network" {
  source = "../../modules/network"

  name_prefix = var.name_prefix
  vpc_cidr    = var.vpc_cidr
  azs         = var.azs
  region      = var.region
}

module "security" {
  source = "../../modules/security"

  name_prefix = var.name_prefix
  vpc_id      = module.network.vpc_id
  admin_cidr  = var.admin_cidr
  enable_ssh  = var.enable_ssh
}

module "storage" {
  source = "../../modules/storage"

  name_prefix          = var.name_prefix
  bucket_prefix        = var.bucket_prefix
  cors_allowed_origins = ["https://${var.app_domain}"]
}

module "secrets" {
  source = "../../modules/secrets"

  name_prefix       = var.name_prefix
  secret_path       = local.secret_path
  region            = var.region
  vpc_id            = module.network.vpc_id
  subnet_ids        = [module.network.public_subnet_ids[0]]
  security_group_id = module.security.vpce_sg_id
}

module "database" {
  source = "../../modules/database"

  name_prefix       = var.name_prefix
  subnet_ids        = module.network.private_subnet_ids
  security_group_id = module.security.db_sg_id

  instance_class = var.db_instance_class
  engine_version = var.db_engine_version
}

module "compute" {
  source = "../../modules/compute"

  name_prefix       = var.name_prefix
  subnet_id         = module.network.public_subnet_ids[0]
  security_group_id = module.security.app_sg_id

  instance_type = var.instance_type

  app_bucket_arn       = module.storage.app_bucket_arn
  artifacts_bucket_arn = module.storage.artifacts_bucket_arn
  secret_arns          = module.secrets.secret_arn_list
  db_master_secret_arn = module.database.master_secret_arn
  kms_key_arn          = module.database.kms_key_arn
  db_instance_arn      = module.database.instance_arn
}

module "cicd" {
  source = "../../modules/cicd"

  name_prefix           = var.name_prefix
  app_instance_tag_name = "${var.name_prefix}-app"
  sns_topic_arn         = aws_sns_topic.alerts.arn
}
