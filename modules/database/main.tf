resource "aws_db_subnet_group" "main" {
  name        = "${var.name_prefix}-db-subnet-group"
  description = "Private subnets across two AZs"
  subnet_ids  = var.subnet_ids

  tags = { Name = "${var.name_prefix}-db-subnet-group" }
}

# ---------------------------------------------------------------------------
# KMS key for storage encryption
# ---------------------------------------------------------------------------

resource "aws_kms_key" "rds" {
  description             = "${var.name_prefix} RDS storage encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = { Name = "${var.name_prefix}-kms-rds" }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# ---------------------------------------------------------------------------
# Parameter group
#
# Laravel needs utf8mb4 for multi-language i18n -- non-Latin scripts and emoji
# both break on plain utf8. MySQL 8 defaults are close but the collation is
# worth pinning explicitly rather than inheriting.
# ---------------------------------------------------------------------------

resource "aws_db_parameter_group" "main" {
  name        = "${var.name_prefix}-mysql8"
  family      = "mysql8.0"
  description = "Laravel-tuned MySQL 8 parameters"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  # Log queries slower than 2s -- useful once real traffic arrives
  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# The instance
# ---------------------------------------------------------------------------

resource "aws_db_instance" "main" {
  identifier = "${var.name_prefix}-mysql"

  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.database_name
  username = var.master_username

  # AWS generates the password, stores it in a secret it manages, and can
  # rotate it. The password never appears in Terraform state, plan output, or
  # your terminal -- which is why no `password` argument is declared.
  manage_master_user_password = true

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  multi_az               = false # Phase 4 trigger: explicit HA requirement

  parameter_group_name = aws_db_parameter_group.main.name

  backup_retention_period = var.backup_retention_days
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true

  auto_minor_version_upgrade = false # control your own upgrade timing

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.name_prefix}-mysql-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  performance_insights_enabled = false # 7 days is free; enable if needed

  enabled_cloudwatch_logs_exports = ["error", "slowquery"]

  lifecycle {
    prevent_destroy = true

    # timestamp() changes on every plan -- ignore it so plans stay clean
    ignore_changes = [final_snapshot_identifier]
  }
}
