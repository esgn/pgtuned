#!/usr/bin/env bash

# This script pulls images from Docker Hub and run them
# to do a simple check of PostgreSQL configuration

testing_image="esgn/pgtuned-testing"

tags=$(curl "https://registry.hub.docker.com/v2/repositories/esgn/pgtuned-testing/tags?page_size=32" 2>/dev/null | jq -r '.results | .[] | .name')
for tag in $tags
do
  image_name=$testing_image":"$tag
  docker rmi $image_name
  docker pull $image_name
  docker run -d -e POSTGRES_PASSWORD=secret --name pg-testing$tag $image_name
  docker exec -ti pg-testing$tag bash -c "until pg_isready -q; do sleep 5; done"
  docker exec -ti pg-testing$tag bash -c "cat /etc/apt/sources.list.d/pgdg.list"
  docker exec -ti pg-testing$tag bash -c "cat /var/lib/postgresql/data/postgresql.conf" > pg-testing$tag".txt"
  docker stop pg-testing$tag && docker rm pg-testing$tag
done
