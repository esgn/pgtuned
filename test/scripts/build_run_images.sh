#!/usr/bin/env bash

# This scripts build all possible Debian combination 
# of PostgreSQL + PostGIS and outputs PostgreSQL 
# configuration file for checking

declare -a arr=("15|3"
                "14|3"
                "13|3"
                "12|3"
                "11-bullseye|3"
                "11|2.5"
                "10-bullseye|3"
                "10|2.5"
                "10|2.4"
                "9.6-bullseye|3"
                "9.6|2.5"
                "9.6|2.4"
                "9.6|2.3"
                "9.5|3"
                "9.5|2.5"
                "9.5|2.4"
                "9.5|2.3"
                )

IFS='|'
for i in "${arr[@]}"
do
    read -ra ADDR <<< "$i"
    pg_version="${ADDR[0]}"
    postgis_version="${ADDR[1]}"
    docker build --no-cache --build-arg POSTGRES_VERSION=$pg_version --build-arg POSTGIS_VERSION=$postgis_version . -t pg$pg_version-$postgis_version
    docker run -d -e POSTGRES_PASSWORD=secret --name pg$pg_version-$postgis_version pg$pg_version-$postgis_version
    docker exec -ti pg$pg_version-$postgis_version bash -c "until pg_isready -q; do sleep 5; done"
    docker exec -ti pg$pg_version-$postgis_version bash -c "cat /etc/apt/sources.list.d/pgdg.list"
    docker exec -ti pg$pg_version-$postgis_version bash -c "cat /var/lib/postgresql/data/postgresql.conf" > pg$pg_version-$postgis_version.txt
    docker stop pg$pg_version-$postgis_version && docker rm pg$pg_version-$postgis_version
done
