#!/bin/bash
set -e

docker stop mynginx || true
docker rm mynginx || true

docker run -d \
  --name mynginx \
  --restart unless-stopped \
  -p 443:443 \
  -p 8443:8443 \
  -v /home/ubuntu/conf.d:/etc/nginx/conf.d/ \
  -v /home/ubuntu/certs:/etc/nginx/certs/ \
  nginx
