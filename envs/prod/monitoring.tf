# ---------------------------------------------------------------------------
# SNS + CloudWatch alarms
#
# Kept in envs/ rather than a module -- it is a handful of resources that all
# reference other modules' outputs, so a module wrapper adds no reuse value.
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"
  tags = { Name = "${var.name_prefix}-alerts" }
}

resource "aws_sns_topic_subscription" "admin_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.admin_email

  # Confirm via the email AWS sends. Terraform cannot auto-confirm; the
  # subscription sits "pending confirmation" until you click the link.
}

# --- EC2 ---------------------------------------------------------------------

# evaluation_periods x period = how long a breach has to persist before the
# alarm actually fires -- 2 x 300s = 80%+ CPU sustained for 10 minutes, not
# just a single momentary spike.
resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  alarm_name          = "${var.name_prefix}-ec2-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EC2 CPU above 80% for 10 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn] # also notify once CPU drops back below threshold

  dimensions = { InstanceId = module.compute.instance_id }
}

resource "aws_cloudwatch_metric_alarm" "ec2_status" {
  alarm_name          = "${var.name_prefix}-ec2-status-check"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "EC2 instance or system status check failing"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = { InstanceId = module.compute.instance_id }
}

# --- RDS ---------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.name_prefix}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU above 80% for 10 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = { DBInstanceIdentifier = module.database.instance_identifier }
}

# Storage autoscaling is on, but this fires before autoscaling would -- useful
# early warning that something is writing more than expected.
resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.name_prefix}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120 # 5 GB in bytes
  alarm_description   = "RDS free storage below 5GB"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = { DBInstanceIdentifier = module.database.instance_identifier }
}

# db.t4g.small has 2GB RAM. Freeable memory this low means the InnoDB buffer
# pool is under pressure -- the signal to move up a tier.
resource "aws_cloudwatch_metric_alarm" "rds_memory" {
  alarm_name          = "${var.name_prefix}-rds-memory-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 209715200 # 200 MB
  alarm_description   = "RDS freeable memory below 200MB -- consider a larger instance class"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = { DBInstanceIdentifier = module.database.instance_identifier }
}