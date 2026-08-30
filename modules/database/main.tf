# DB Subnet Group -- tells RDS which subnets it's allowed to place its
# network interface(s) in. Required even for a Single-AZ instance; RDS still
# needs a group spanning 2+ AZs in case you switch to Multi-AZ later.
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
  deletion_window_in_days = 30   # mandatory pending-deletion buffer (7-30 days) before AWS destroys the key
  enable_key_rotation     = true # AWS rotates the underlying key material yearly; the key ID/ARN never changes

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
  #
  # master_user_secret_kms_key_id must be set explicitly here: without it,
  # AWS encrypts the managed secret with the default aws/secretsmanager key
  # instead of this key, which would make the EC2 role's "DecryptManagedSecret"
  # kms:Decrypt grant below (on this exact key) point at the wrong key.
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.rds.arn

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage # ceiling for storage autoscaling -- RDS grows the volume on demand up to this
  storage_type          = "gp3"                     # general-purpose SSD; better baseline IOPS/throughput than gp2 at the same price
  storage_encrypted     = true                      # encryption at rest for the data volume, using the KMS key below
  kms_key_id            = aws_kms_key.rds.arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false # no public IP -- reachable only from inside the VPC
  multi_az               = false # Phase 4 trigger: explicit HA requirement

  parameter_group_name = aws_db_parameter_group.main.name

  backup_retention_period = var.backup_retention_days
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true

  auto_minor_version_upgrade = false # control your own upgrade timing

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = false # false = take one last snapshot before deletion (named below)
  final_snapshot_identifier = "${var.name_prefix}-mysql-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  performance_insights_enabled = false # 7 days is free; enable if needed

  # Streams these MySQL log types to CloudWatch Logs so they're searchable
  # and retained even after the instance is gone.
  enabled_cloudwatch_logs_exports = ["error", "slowquery"]

  lifecycle {
    prevent_destroy = true

    # timestamp() changes on every plan -- ignore it so plans stay clean
    ignore_changes = [final_snapshot_identifier]
  }
}
