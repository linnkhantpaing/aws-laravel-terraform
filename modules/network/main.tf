# ---------------------------------------------------------------------------
# Subnet plan — 10.20.0.0/16 carved into four /20s (4,091 usable IPs each)
#
#   10.20.0.0/20    public  AZ-a   EC2 application server
#   10.20.16.0/20   public  AZ-b   reserved — ALB in Phase 3
#   10.20.32.0/20   private AZ-a   RDS primary
#   10.20.48.0/20   private AZ-b   reserved — RDS subnet group requirement
#
# Large gaps left between blocks so future tiers (ElastiCache, ECS) slot in
# without renumbering.
# ---------------------------------------------------------------------------

locals {
  public_cidrs  = [cidrsubnet(var.vpc_cidr, 4, 0), cidrsubnet(var.vpc_cidr, 4, 1)]
  private_cidrs = [cidrsubnet(var.vpc_cidr, 4, 2), cidrsubnet(var.vpc_cidr, 4, 3)]
}

# VPC -- an isolated, private network in this AWS account/region. Everything
# else in this module (subnets, routing, endpoints) lives inside it.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # turns on the VPC's internal DNS resolver (the .2 address)
  enable_dns_hostnames = true # required for RDS endpoint resolution

  tags = { Name = "${var.name_prefix}-vpc" }
}

# Internet Gateway -- the VPC's only door to the public internet. Attaching
# it does nothing by itself; a subnet only gets internet access once its
# route table has a route pointing traffic at this resource (below).
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name_prefix}-igw" }
}

# ---------------------------------------------------------------------------
# Public subnets — EC2 today, ALB later
# ---------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_cidrs[count.index]
  availability_zone = var.azs[count.index]

  # Explicitly false. The EC2 instance gets a stable Elastic IP instead of an
  # auto-assigned one that changes on every stop/start.
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name_prefix}-public-${var.azs[count.index]}"
    Tier = "public"
  }
}

# ---------------------------------------------------------------------------
# Private subnets — RDS. No NAT Gateway by design (~$35/mo saved).
# Nothing in here needs outbound internet in Phase 1.
# ---------------------------------------------------------------------------

resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.name_prefix}-private-${var.azs[count.index]}"
    Tier = "private"
  }
}

# ---------------------------------------------------------------------------
# Routing
# ---------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name_prefix}-rt-public" }
}

# "Send anything not otherwise matched to the Internet Gateway" -- this one
# route is what actually makes the subnets below "public".
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Route tables aren't tied to subnets by themselves -- this association is
# what makes each public subnet actually use the route table above.
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route table has no 0.0.0.0/0 route — that isolation is the point.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name_prefix}-rt-private" }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ---------------------------------------------------------------------------
# S3 Gateway Endpoint — free, and keeps S3 traffic off the public internet.
# Attached to both route tables so EC2 and (future) private resources use it.
# ---------------------------------------------------------------------------

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.public.id,
    aws_route_table.private.id,
  ]

  tags = { Name = "${var.name_prefix}-vpce-s3" }
}

# ---------------------------------------------------------------------------
# Default security group — locked to deny-all.
# AWS creates this automatically and it allows all internal traffic by default.
# Managing it here empties it, so nothing accidentally lands in a permissive SG.
# ---------------------------------------------------------------------------

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name_prefix}-sg-default-DO-NOT-USE" }
  # no ingress or egress blocks = deny everything
}