# ---------------------------------------------------------------------------
# Security groups are stateful virtual firewalls attached to ENIs/instances:
# every rule below is an ALLOW -- there's no explicit "deny", traffic that
# doesn't match any rule is dropped by default. Return traffic for anything
# already allowed in is let back out automatically (and vice versa), which is
# why the RDS and VPC-endpoint groups below need no egress rules of their own.
#
# All security groups live here so that resources referencing each other's SGs
# do not create a module-level dependency cycle.
#
# Rules are declared as separate resources (not inline blocks) so a rule change
# does not force SG replacement, which would ripple into every attached resource.
# ---------------------------------------------------------------------------

# --- Application server ------------------------------------------------------

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-sg-app"
  description = "Application server: web in, all out"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-sg-app" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS and WSS from anywhere -- Nginx proxies Reverb on 443"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "app_http" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP -- redirect to HTTPS, and ACME challenges"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh" {
  count = var.enable_ssh ? 1 : 0

  security_group_id = aws_security_group.app.id
  description       = "SSH from admin"
  cidr_ipv4         = var.admin_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound: packages, AI APIs, Bunny Stream, SMTP"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # "-1" = all protocols/ports, AWS's way of saying "any"
}

# --- RDS ---------------------------------------------------------------------

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-sg-rds"
  description = "MySQL from the application server only"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-sg-rds" }

  lifecycle {
    create_before_destroy = true
  }
}

# referenced_security_group_id (instead of a CIDR) scopes this rule to "any
# ENI wearing the app SG" -- it tracks the app servers automatically even if
# their IPs change, rather than a static IP range that could drift stale.
resource "aws_vpc_security_group_ingress_rule" "db_mysql" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL from application server"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

# No egress -- RDS never initiates outbound connections.

# --- VPC interface endpoints (Secrets Manager) -------------------------------

resource "aws_security_group" "vpce" {
  name        = "${var.name_prefix}-sg-vpce"
  description = "HTTPS from the application server to VPC interface endpoints"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-sg-vpce" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpce_https" {
  security_group_id            = aws_security_group.vpce.id
  description                  = "HTTPS from application server"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}
