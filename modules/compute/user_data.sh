#!/bin/bash
set -euxo pipefail

# Runs once at first boot. Installs the runtime; CodeDeploy delivers the app.
# Must be saved with LF line endings -- CRLF breaks bash on Linux.

# --- Wait for internet access ------------------------------------------------
# This subnet has no NAT gateway; outbound internet only works once the
# Elastic IP is associated (modules/compute/main.tf), which Terraform does
# AFTER this instance exists -- but cloud-init starts running this script
# independently as soon as the OS boots, with no guarantee the EIP has
# attached yet. Without this wait, dnf update below can fail on a fresh
# instance with no network, and `set -e` aborts the whole script right there.
for i in $(seq 1 30); do
  if curl -fsS -m 5 https://checkip.amazonaws.com >/dev/null 2>&1; then
    break
  fi
  echo "Waiting for internet connectivity (attempt $i/30)..."
  sleep 5
done

dnf update -y

# --- PHP 8.3 + extensions Laravel needs -------------------------------------
dnf install -y \
  nginx \
  php8.3 php8.3-fpm php8.3-cli php8.3-mysqlnd php8.3-mbstring \
  php8.3-xml php8.3-gd php8.3-bcmath php8.3-intl php8.3-zip \
  php8.3-opcache php8.3-sodium \
  git unzip jq ruby wget

# --- Composer ----------------------------------------------------------------
# HOME is unset under cloud-init, and the installer treats that as a fatal
# environment error -- export it or the whole script dies here.
export HOME=/root
curl -sS https://getcomposer.org/installer | php -- \
  --install-dir=/usr/local/bin --filename=composer

# --- Node 20 for Vite asset builds ------------------------------------------
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs

# --- Supervisor: queue worker and Reverb both need persistent processes ------
# AL2023 ships no supervisor RPM -- install via pip and hand-roll the unit.
dnf install -y python3-pip
pip3 install supervisor
mkdir -p /etc/supervisord.d
echo_supervisord_conf > /etc/supervisord.conf
sed -i \
  -e 's|;\[include\]|[include]|' \
  -e 's|;files = relative/directory/\*.ini|files = /etc/supervisord.d/*.ini|' \
  /etc/supervisord.conf

cat > /etc/systemd/system/supervisord.service << 'UNIT'
[Unit]
Description=Supervisor process control system for UNIX
After=network.target

[Service]
ExecStart=/usr/local/bin/supervisord -n -c /etc/supervisord.conf
ExecStop=/usr/local/bin/supervisorctl shutdown
ExecReload=/usr/local/bin/supervisorctl reload
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable supervisord

# --- CodeDeploy agent --------------------------------------------------------
# $${region} below is filled in by Terraform's templatefile() -- see modules/compute/main.tf
cd /tmp
wget "https://aws-codedeploy-${region}.s3.${region}.amazonaws.com/latest/install"
chmod +x ./install
./install auto
systemctl enable codedeploy-agent

# --- Certbot for Let's Encrypt ----------------------------------------------
dnf install -y certbot python3-certbot-nginx

# --- Application directory ---------------------------------------------------
mkdir -p /var/www/myapp
chown -R nginx:nginx /var/www/myapp

# --- PHP-FPM runs as nginx so Laravel's storage/ stays writable -------------
sed -i 's/^user = apache/user = nginx/' /etc/php-fpm.d/www.conf
sed -i 's/^group = apache/group = nginx/' /etc/php-fpm.d/www.conf

systemctl enable --now php-fpm
systemctl enable --now nginx

# Nginx vhost, Supervisor programs, and TLS are configured during the first
# deploy -- they depend on the domain name and on the release being present.
