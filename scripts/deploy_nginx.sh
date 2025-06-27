#!/bin/bash
set -e

DOMAIN="merry-bot.fursa.click"
CERT_DIR="/home/ubuntu/certs"
NGINX_CONTAINER_NAME="mynginx"

# Step 1: Issue/renew certificate if needed
if [ ! -f "$CERT_DIR/fullchain.pem" ] || [ ! -f "$CERT_DIR/privkey.pem" ]; then
  echo "🔐 No existing certs found. Issuing new cert from Let's Encrypt..."
  sudo certbot certonly --standalone --agree-tos --no-eff-email --email your@email.com -d "$DOMAIN"

  echo "📁 Copying certs to $CERT_DIR..."
  sudo cp /etc/letsencrypt/live/"$DOMAIN"/fullchain.pem "$CERT_DIR/"
  sudo cp /etc/letsencrypt/live/"$DOMAIN"/privkey.pem "$CERT_DIR/"
else
  echo "🔄 Attempting to renew existing cert..."
  sudo certbot renew --quiet

  echo "🔁 Copying latest certs to $CERT_DIR..."
  sudo cp /etc/letsencrypt/live/"$DOMAIN"/fullchain.pem "$CERT_DIR/"
  sudo cp /etc/letsencrypt/live/"$DOMAIN"/privkey.pem "$CERT_DIR/"
fi

# Step 2: Restart Docker NGINX container
docker stop "$NGINX_CONTAINER_NAME" || true
docker rm "$NGINX_CONTAINER_NAME" || true

docker run -d \
  --name "$NGINX_CONTAINER_NAME" \
  --restart unless-stopped \
  -p 443:443 \
  -p 8443:8443 \
