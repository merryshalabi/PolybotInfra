#!/bin/bash
set -e

docker stop mynginx || true
docker rm mynginx || true

mkdir -p /home/ubuntu/conf.d
mkdir -p /home/ubuntu/certs

docker run -d \
  --name mynginx \
  -p 443:443 \
  -p 8443:8443 \
  -v /home/ubuntu/conf.d:/etc/nginx/conf.d/ \
  -v /home/ubuntu/certs:/etc/nginx/certs/ \
  nginx
