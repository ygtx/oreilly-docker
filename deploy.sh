#!/bin/bash
set -e

echo "Starting indentidock system"

docker run -d --restart=always --name redis redis:3
docker run -d --restart=always --name dnmonster amouat/dnmonster:1.0
docker run -d --restart=always \
  --link dnmonster:dnmonster \
  --link redis:redis \
  -e ENV=PROD \
  --name identidock amouat/identidock:1.0
docker run -d --restart=always \
  --name proxy \
  --link identidock:identidock \
  -p 80:80 \
  -e NGINX_HOST=104.131.177.213 \
  -e NGINX_PROXY=http://identidock:9090 \
  amouat/proxy:1.0

echo "Started"
