data "aws_caller_identity" "current" {}

locals {
  state_bucket = "${var.prefix}-tfstate"

  # GitHub now embeds immutable numeric IDs in the OIDC sub claim --
  # "repo:owner@<owner_id>/repo@<repo_id>:ref:..." instead of the old plain
  # "repo:owner/repo:ref:...". The "@*" wildcards absorb those IDs.
  infra_sub = "repo:${var.github_owner}@*/${var.infra_repo}@*"
  app_sub   = "repo:${var.github_owner}@*/${var.app_repo}@*"
}

# ---------------------------------------------------------------------------
# Terraform state bucket
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "tfstate" {
  bucket = local.state_bucket

  # State files describe your whole infrastructure. Losing this bucket is far
  # worse than losing any single resource.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# ---------------------------------------------------------------------------
# GitHub OIDC provider -- lets Actions authenticate with no stored AWS keys
# ---------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # AWS no longer validates this thumbprint for GitHub -- it uses its own
  # trusted CA store. The value is a required-field placeholder.
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
}

# ---------------------------------------------------------------------------
# Role 1: terraform PLAN -- read-only, assumable from pull requests
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "tf_plan_trust" {
  statement {
    effect = "Allow"
    # TagSession is required alongside AssumeRoleWithWebIdentity because
    # aws-actions/configure-aws-credentials tags the session with GitHub
    # run context by default -- without it, AssumeRoleWithWebIdentity
    # itself is rejected with a misleading "Not authorized" error.
    actions = ["sts:AssumeRoleWithWebIdentity", "sts:TagSession"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.infra_sub}:pull_request"]
    }
  }
}

resource "aws_iam_role" "tf_plan" {
  name               = "${var.prefix}-gha-tf-plan"
  description        = "GitHub Actions: terraform plan on PRs (read-only)"
  assume_role_policy = data.aws_iam_policy_document.tf_plan_trust.json
}

resource "aws_iam_role_policy_attachment" "tf_plan_readonly" {
  role       = aws_iam_role.tf_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# plan still needs to write the state lock file
resource "aws_iam_role_policy" "tf_plan_state" {
  name = "state-lock"
  role = aws_iam_role.tf_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:DeleteObject"]
      Resource = "${aws_s3_bucket.tfstate.arn}/*"
    }]
  })
}

# ---------------------------------------------------------------------------
# Role 2: terraform APPLY -- trusted only from the `prod` GitHub Environment
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "tf_apply_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity", "sts:TagSession"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # `environment:prod` -- not a branch. The GitHub Environment's required
    # reviewer becomes a hard gate: no approval, no token, no apply.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.infra_sub}:environment:prod"]
    }
  }
}

resource "aws_iam_role" "tf_apply" {
  name               = "${var.prefix}-gha-tf-apply"
  description        = "GitHub Actions: terraform apply (prod environment only)"
  assume_role_policy = data.aws_iam_policy_document.tf_apply_trust.json
}

# Admin because Terraform must create IAM roles, which needs iam:* anyway.
# Scope this down in Phase 2 once the resource set stops changing.
resource "aws_iam_role_policy_attachment" "tf_apply_admin" {
  role       = aws_iam_role.tf_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ---------------------------------------------------------------------------
# Role 3: app deploy -- narrow. Upload artifact, trigger CodeDeploy. Nothing else.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "app_deploy_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity", "sts:TagSession"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.app_sub}:*"]
    }
  }
}

resource "aws_iam_role" "app_deploy" {
  name               = "${var.prefix}-gha-app-deploy"
  description        = "GitHub Actions: upload release artifact and trigger CodeDeploy"
  assume_role_policy = data.aws_iam_policy_document.app_deploy_trust.json
}

# Wildcard ARNs because these resources do not exist yet -- the main stack
# creates them. Names are constrained by prefix.
resource "aws_iam_role_policy" "app_deploy" {
  name = "artifact-and-deploy"
  role = aws_iam_role.app_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = "arn:aws:s3:::${var.prefix}-artifacts/*"
      },
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:GetApplicationRevision"
        ]
        Resource = "*"
      },
      {
        # Vite bakes VITE_REVERB_APP_KEY into the compiled JS at build time --
        # the runtime .env that after_install.sh generates on the instance
        # never reaches an already-built bundle, so CI needs the real value
        # before "npm run build", not just the instance at deploy time.
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:myapp/prod/reverb-*"
      }
    ]
  })
}
