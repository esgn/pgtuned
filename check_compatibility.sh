#!/usr/bin/env bash

# This script runs official PostgreSQL Docker images
# and gets the available PostGIS version for each of them.
# Also ouputs the distribution used for each image. 

pg_versions="14 13 12 11 10 9.6 9.5"

for v in $pg_versions
do
  echo "Examining postgres:$v"
  echo "######################"
  docker run -d -e POSTGRES_PASSWORD=secret --name pg$v postgres:$v >/dev/null 2>&1
  c="apt update >/dev/null 2>&1 && apt-cache search $v-postgis | grep -Po '(?<=postgresql-$v-postgis-)([0-9\.]*)' | uniq | xargs "
  versions=$(docker exec -ti pg$v bash -c "$c")
  distrib=$(docker exec -ti pg$v bash -c 'cat /etc/os-release' | grep -Po '(?<=PRETTY_NAME=")(.*)(?=")')
  echo "Available PostGIS versions : "$versions
  echo "Running on "$distrib
  docker rm -f pg$v >/dev/null 2>&1
  echo
done
