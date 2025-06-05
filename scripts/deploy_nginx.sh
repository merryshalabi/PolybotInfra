#!/bin/bash
set -e

docker stop mynginx || true
docker rm mynginx || true

docker run -d \
  --name mynginx \
  -p 443:443 \
  -p 8443:8443 \
  -v /home/ubuntu/conf.d:/etc/nginx/conf.d/ \
  -v /etc/letsencrypt/live/merry-bot.fursa.click:/etc/nginx/certs:ro \
  nginx
