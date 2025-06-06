#!/bin/bash
set -e

# Create network if it doesn't exist
docker network inspect nginx-proxy >/dev/null 2>&1 || \
  docker network create nginx-proxy

# Stop and remove existing containers
docker stop nginx-proxy nginx-proxy-letsencrypt || true
docker rm nginx-proxy nginx-proxy-letsencrypt || true

# Start the NGINX reverse proxy
docker run -d \
  --name nginx-proxy \
  --restart unless-stopped \
  --network nginx-proxy \
  -p 80:80 -p 443:443 \
  -v /etc/nginx/certs:/etc/nginx/certs:ro \
  -v /etc/nginx/vhost.d:/etc/nginx/vhost.d \
  -v /usr/share/nginx/html:/usr/share/nginx/html \
  -v /var/run/docker.sock:/tmp/docker.sock:ro \
  jwilder/nginx-proxy

# Start the Let's Encrypt companion container
docker run -d \
  --name nginx-proxy-letsencrypt \
  --restart unless-stopped \
  --network nginx-proxy \
  -v /etc/nginx/certs:/etc/nginx/certs \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  --volumes-from nginx-proxy \
  jrcs/letsencrypt-nginx-proxy-companion
