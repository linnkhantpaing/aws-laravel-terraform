# ---------------------------------------------------------------------------
# Secret CONTAINERS only. Values are never in Terraform.
#
# Terraform state stores every managed attribute in readable JSON -- putting a
# secret value in code means the plaintext lands in your state bucket and in
# every plan output. So we create empty secrets here and populate them once by
# hand via the CLI. `ignore_changes` then stops Terraform reverting them.
# ---------------------------------------------------------------------------

locals {
  secrets = {
    db_credentials = {
      name        = "${var.secret_path}/db"
      description = "Additional DB connection details (master password is AWS-managed)"
    }
    app_key = {
      name        = "${var.secret_path}/app-key"
      description = "Laravel APP_KEY -- encrypts sessions and cookies"
    }
    anthropic_api_key = {
      name        = "${var.secret_path}/anthropic-api-key"
      description = "Claude API key for the app's AiGateway"
    }
    openai_api_key = {
      name        = "${var.secret_path}/openai-api-key"
      description = "OpenAI API key for the app's AiGateway"
    }
    bunny_stream = {
      name        = "${var.secret_path}/bunny-stream"
      description = "Bunny Stream library ID, API key, and token signing key"
    }
    smtp_credentials = {
      name        = "${var.secret_path}/smtp"
      description = "SMTP host, port, username, password for Laravel mail"
    }
    reverb = {
      name        = "${var.secret_path}/reverb"
      description = "Laravel Reverb app ID, key, and secret"
    }
    manual_payment_provider = {
      name        = "${var.secret_path}/manual-payment-provider"
      description = "Example: account/QR reference info for a manual, non-API local payment method -- replace with whatever your app integrates"
    }
    google_oauth = {
      name        = "${var.secret_path}/google-oauth"
      description = "Google OAuth client ID and secret for Socialite sign-in"
    }
  }
}

resource "aws_secretsmanager_secret" "this" {
  for_each = local.secrets

  name                    = each.value.name
  description             = each.value.description
  recovery_window_in_days = var.recovery_window_days

  tags = {
    Name = "${var.name_prefix}-${each.key}"
  }
}

# Seed each secret with placeholder JSON so the app gets valid JSON rather than
# an error before you have populated it. Real values are set out-of-band.
resource "aws_secretsmanager_secret_version" "placeholder" {
  for_each = aws_secretsmanager_secret.this

  secret_id     = each.value.id
  secret_string = jsonencode({ placeholder = "set via aws cli -- see README" })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ---------------------------------------------------------------------------
# VPC Interface Endpoint for Secrets Manager
#
# Secrets Manager offers no Gateway endpoint (unlike S3) -- Interface only.
# Without this, the EC2 instance reaches it over the Internet Gateway, which
# works but sends credential traffic across the public internet. ~$9.51/mo.
# ---------------------------------------------------------------------------

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [var.security_group_id]
  private_dns_enabled = true # makes the standard AWS SDK endpoint resolve privately

  tags = { Name = "${var.name_prefix}-vpce-secretsmanager" }
}
