# ---------------------------------------------------------------------------
# AMI -- latest Amazon Linux 2023, resolved at plan time
# ---------------------------------------------------------------------------

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------------------------------------------------------------------------
# IAM instance role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.name_prefix}-ec2-app"
  description        = "Application server: S3, Secrets Manager, CloudWatch, SSM"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.name_prefix}-ec2-app"
  role = aws_iam_role.app.name
}

# Session Manager -- browser shell with no open SSH port
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_iam_policy_document" "app" {
  statement {
    sid    = "AppBucketObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectVersion",
    ]
    resources = ["${var.app_bucket_arn}/*"]
  }

  statement {
    sid       = "AppBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [var.app_bucket_arn]
  }

  statement {
    sid       = "ArtifactDownload"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${var.artifacts_bucket_arn}/*"]
  }

  statement {
    sid       = "ReadSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = concat(var.secret_arns, [var.db_master_secret_arn])
  }

  statement {
    sid       = "DecryptManagedSecret"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }

  statement {
    sid       = "ResolveDbEndpoint"
    effect    = "Allow"
    actions   = ["rds:DescribeDBInstances"]
    resources = [var.db_instance_arn]
  }
}

resource "aws_iam_role_policy" "app" {
  name   = "app-access"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app.json
}

# ---------------------------------------------------------------------------
# Instance
# ---------------------------------------------------------------------------

resource "aws_instance" "app" {
  ami           = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_name

  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.app.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_tokens   = "required" # IMDSv2 only -- blocks SSRF credential theft
    http_endpoint = "enabled"
  }

  user_data                   = file("${path.module}/user_data.sh")
  user_data_replace_on_change = false # editing the script must not rebuild the box

  tags = {
    Name = "${var.name_prefix}-app"
    Role = "application-server"
  }

  lifecycle {
    ignore_changes = [ami] # new AMI releases should not trigger replacement
  }
}

# ---------------------------------------------------------------------------
# Elastic IP -- stable address for your registrar's A record
# ---------------------------------------------------------------------------

resource "aws_eip" "app" {
  domain   = "vpc"
  instance = aws_instance.app.id

  tags = { Name = "${var.name_prefix}-eip-app" }
}
