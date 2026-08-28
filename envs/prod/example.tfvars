# Copy to terraform.tfvars and fill in. terraform.tfvars is gitignored.

app_domain  = "myapp.example.com"
admin_email = "you@example.com"

# Narrow once you have a static IP, or set enable_ssh = false and use
# Session Manager instead.
admin_cidr = "0.0.0.0/0"
enable_ssh = true
