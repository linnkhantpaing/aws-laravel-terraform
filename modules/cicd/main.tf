# ---------------------------------------------------------------------------
# CodeDeploy service role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy" {
  name               = "${var.name_prefix}-codedeploy"
  description        = "CodeDeploy service role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------

resource "aws_codedeploy_app" "main" {
  name             = "${var.name_prefix}-app"
  compute_platform = "Server"
}

# ---------------------------------------------------------------------------
# Deployment group
#
# In-place deployment. Blue/green needs an ALB and an ASG -- neither exists
# until Phase 3, so in-place is the only option and it is fine for one instance.
# ---------------------------------------------------------------------------

resource "aws_codedeploy_deployment_group" "main" {
  app_name              = aws_codedeploy_app.main.name
  deployment_group_name = "${var.name_prefix}-prod"
  service_role_arn      = aws_iam_role.codedeploy.arn

  deployment_config_name = "CodeDeployDefault.OneAtATime"

  deployment_style {
    deployment_type   = "IN_PLACE"
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
  }

  # Tag-based targeting rather than a hardcoded instance ID -- survives
  # instance replacement without a Terraform change.
  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = var.app_instance_tag_name
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  dynamic "trigger_configuration" {
    for_each = var.sns_topic_arn != "" ? [1] : []

    content {
      trigger_events = [
        "DeploymentFailure",
        "DeploymentRollback",
      ]
      trigger_name       = "deployment-alerts"
      trigger_target_arn = var.sns_topic_arn
    }
  }
}
