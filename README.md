# aws-laravel-terraform

Terraform for the Phase 1 architecture: single EC2 application server (Laravel 13 +
React/Inertia + Reverb), RDS MySQL in private subnets, two S3 buckets, Secrets Manager,
and CodeDeploy — all in `ap-southeast-7` (example region; swap for whichever region you deploy to).

## Layout

```
bootstrap/          Applied ONCE by hand. Creates the state bucket + GitHub OIDC roles.
                    Uses local state — it cannot store state in a bucket it hasn't made.
modules/
  network/          VPC, IGW, 4 subnets, route tables, S3 gateway endpoint
  security/         All security groups (centralized to avoid dependency cycles)
  storage/          Application bucket + deployment artifact bucket
  secrets/          Secrets Manager containers + VPC interface endpoint
  database/         RDS MySQL 8, KMS key, parameter group
  compute/          EC2, IAM instance profile, Elastic IP, bootstrap script
  cicd/             CodeDeploy application + deployment group
envs/prod/          Wires the modules together. One state file. The only environment.
```

Dependency order: `network → security → storage → secrets → database → compute → cicd`

## Apply order

### 1. Bootstrap (once, from your laptop)

```bash
cd bootstrap
cp example.tfvars terraform.tfvars    # fill in github_owner and app_repo
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

Note the outputs. `state_bucket` feeds `envs/prod/backend.tf` in step 2. The
three GitHub OIDC role ARNs aren't consumed by anything in this repo (no CI
workflow ships here) -- they're provisioned so you can wire up your own
plan/apply/deploy pipeline against the same trust pattern if you want one.

### 2. Enable the remote backend

Uncomment the `backend "s3"` block in `envs/prod/backend.tf` and set `bucket` to the
`state_bucket` output from step 1.

This repo requires Terraform >= 1.10 (`required_version` in `providers.tf`) for
native S3 state locking via `use_lockfile`. To support an older Terraform version
instead, you'd need to relax `required_version`, remove `use_lockfile = true`, and
add your own DynamoDB lock table to `bootstrap/`.

### 3. Main stack

```bash
cd envs/prod
cp example.tfvars terraform.tfvars    # fill in app_domain and admin_email
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

RDS takes 10–15 minutes. Confirm the SNS subscription emails when they arrive —
alarms don't notify until you click the link.

## Verify before the first apply

These four assumptions are baked into defaults and may be wrong for `ap-southeast-7`:

```bash
# AZ names — defaults assume 7a and 7b
aws ec2 describe-availability-zones --region ap-southeast-7 \
  --query "AvailabilityZones[].ZoneName"

# MySQL minor version — default is 8.0.46
aws rds describe-db-engine-versions --engine mysql --region ap-southeast-7 \
  --query "DBEngineVersions[?starts_with(EngineVersion,'8.0')].EngineVersion" --output text

# db.t4g.small offered in-region?
aws rds describe-orderable-db-instance-options --engine mysql --region ap-southeast-7 \
  --query "OrderableDBInstanceOptions[?DBInstanceClass=='db.t4g.small'].DBInstanceClass" \
  --output text

# CodeDeploy agent bucket (referenced in modules/compute/user_data.sh)
aws s3 ls s3://aws-codedeploy-ap-southeast-7/latest/ --region ap-southeast-7 --no-sign-request
```

## Secrets

Terraform creates empty secret containers. Values are set out-of-band so they never
enter state or git:

```bash
aws secretsmanager put-secret-value \
  --secret-id myapp/prod/anthropic-api-key \
  --secret-string '{"api_key":"sk-ant-..."}'
```

The RDS master password is the exception — AWS generates and stores it
(`manage_master_user_password = true`). Fetch it at deploy time from the ARN in the
`db_master_secret_arn` output. You never handle it directly.

## Deliberate omissions

| Not included | Why |
|---|---|
| NAT Gateway | ~$35/mo, and nothing in the private subnets needs outbound internet |
| Multi-AZ RDS | Phase 4 trigger: an explicit business HA requirement |
| ElastiCache | Phase 2. A single Reverb process needs no pub/sub backplane |
| ALB | Phase 3. Nginx terminates TLS on the instance via Let's Encrypt |
| Route 53 | Domain is registered elsewhere — point an A record at `app_public_ip` |
| Staging environment | Doubles the bill; add `envs/staging/` by copying `envs/prod/` |

## Security notes

- `admin_cidr` defaults to `0.0.0.0/0`, which leaves SSH open to the internet.
  Session Manager is wired via the instance role — once you've confirmed browser
  shell access works, set `enable_ssh = false` and port 22 closes entirely.
- IMDSv2 is required on the instance (`http_tokens = "required"`), blocking the
  SSRF-to-credential-theft path.
- `prevent_destroy` guards the state bucket, the application bucket, and the RDS
  instance. Destroying any of them requires deliberately editing the lifecycle block.
- The application bucket is meant for private, user-generated files (uploads, exports,
  generated documents) — access is locked down with Block Public Access and presigned
  URLs, not by keeping this repo private. Treat whatever you actually store there as
  production data and adjust retention/versioning to match its sensitivity.
