#!/usr/bin/env bash

# Place ourselves in scripts directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR" || exit

# This script pulls images from Docker Hub and run them
# to do a simple check of PostgreSQL configuration

set -e

testing_image="esgn/pgtuned-testing"

# get all available tags from docker hub registry
tags=$(curl "https://registry.hub.docker.com/v2/repositories/$testing_image/tags?page_size=100" 2>/dev/null | jq -r '.results | .[] | .name')

# Iterate over tags
for tag in $tags; do
  image_name=$testing_image":"$tag
  docker rmi --force "$image_name" &>/dev/null
  docker pull -q "$image_name"
  docker run -d -e POSTGRES_PASSWORD=secret --name "pg-testing$tag" "$image_name"
  docker exec -ti "pg-testing$tag" bash -c "until pg_isready -q; do sleep 5; done"
  docker exec -ti "pg-testing$tag" bash -c "cat /var/lib/postgresql/data/postgresql.conf" > "pg-testing$tag.txt"
  docker stop "pg-testing$tag" &>/dev/null && docker rm --force "pg-testing$tag" &>/dev/null
done
 