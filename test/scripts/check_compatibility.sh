#!/usr/bin/env bash

# This script runs official PostgreSQL Docker images
# and gets the available PostGIS version for each of them.
# Also ouputs the distribution used for each image. 

pg_versions="15 14 13 12 11 10 9.6 9.5"

for v in $pg_versions
do
  echo "Examining postgres:$v"
  echo "######################"
  docker run -d -e POSTGRES_PASSWORD=secret --name pg$v postgres:$v >/dev/null 2>&1
  codename=$(docker exec -ti pg$v bash -c "source /etc/os-release && echo -n \$VERSION_CODENAME")
  if [ "$codename" = "stretch" ]
  then
    echo "applying apt-archive.postgres.org patch"
    c="cd /etc/apt/sources.list.d/ && mv pgdg.list pgdg.list.backup"
    docker exec -ti pg$v bash -c "$c"
    c="apt-get -qq update && DEBCONF_NOWARNINGS='yes' apt-get install apt-transport-https -y > /dev/null"
    docker exec -ti pg$v bash -c "$c"
    c="cd /etc/apt/sources.list.d/ && mv pgdg.list.backup pgdg.list"
    docker exec -ti pg$v bash -c "$c"
    c="sed -i 's/http\:\/\/apt\.postgres/https\:\/\/apt-archive\.postgres/' /etc/apt/sources.list.d/pgdg.list"
    docker exec -ti pg$v bash -c "$c"
    c="apt-get -qq update"
    docker exec -ti pg$v bash -c "$c"
  fi
  c="apt update >/dev/null 2>&1 && apt-cache search $v-postgis | grep -Po '(?<=postgresql-$v-postgis-)([0-9\.]*)' | uniq | xargs "
  versions=$(docker exec -ti pg$v bash -c "$c")
  distrib=$(docker exec -ti pg$v bash -c "source /etc/os-release && echo -n \$PRETTY_NAME")
  echo "Available PostGIS versions : "$versions
  echo "Running on "$distrib
  docker rm -f pg$v >/dev/null 2>&1
  echo
done
