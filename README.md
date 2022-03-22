# PGTuned

PGTuned is a first attempt at building a Docker PostgreSQL image that includes basic performance tuning based on available ressources and contemplated use-case.  
This project includes a bash script equivalent of [PGTune](https://github.com/le0pard/pgtune).

## `pgtune.sh`

This `pgtune.sh` script is a bash port of [PGTune](https://github.com/le0pard/pgtune).  
In addition, this script will automatically determine missing parameters based on system settings.

```
Usage: pgtune.sh [-h] [-v PG_VERSION] [-t DB_TYPE] [-m TOTAL_MEM] [-u CPU_COUNT] [-c MAX_CONN] [-s STGE_TYPE]

This script is a bash port of PGTune (https://pgtune.leopard.in.ua).
It produces a postgresql.conf file based on supplied parameters.

  -h                  display this help and exit
  -v PG_VERSION       (optional) PostgreSQL version
                      accepted values: 9.5, 9.6, 10, 11, 12, 13, 14
                      default value: 14
  -t DB_TYPE          (optional) For what type of application is PostgreSQL used
                      accepted values: web, oltp, dw, desktop, mixed
                      default value: web
  -m TOTAL_MEM        (optional) how much memory can PostgreSQL use
                      accepted values: integer with unit ("MB" or "GB") between 1 and 9999 and greater than 512MB
                      default value: this script will try to determine the total memory and exit in case of failure
  -u CPU_COUNT        (optional) number of CPUs, which PostgreSQL can use
                      accepted values: integer between 1 and 9999
                      CPUs = threads per core * cores per socket * sockets
                      default value: this script will try to determine the CPUs count and exit in case of failure
  -c MAX_CONN         (optional) Maximum number of PostgreSQL client connections
                      accepted values: integer between 20 and 9999
                      default value: preset corresponding to db_type
  -s STGE_TYPE        (optional) Type of data storage device used with PostgreSQL
                      accepted values: hdd, ssd, san
                      default value: this script will try to determine the storage type (san not supported) and use hdd
                      value in case of failure.
```

## `test.sh`

The `test.sh` compares some `pgtune.sh` results with pre-generated `postgresql.conf` available in `test_files/`.

## Building and running Docker image

The PGTuned image is built on top of the [official PostgreSQL Docker image](https://hub.docker.com/_/postgres). The default tag used is `14`.  
At container startup `pgtuned.sh` script replaces the default `postgresql.conf` file by a new one created with `pgtune.sh` using supplied options.

### Building PGTuned image

Building the PGTuned docker image accepts two optional arguments `POSTGRES_VERSION` and `POSTGIS_VERSION`.

The command below builds the `pgtuned` image using `postgres:14` image **without PostGIS** :

```
docker build --no-cache . -t pgtuned
```

The following command builds the `pgtuned:13` image using `postgres:13` image **without PostGIS** :

```
docker build --no-cache --build-arg POSTGRES_VERSION=13 . -t pgtuned:13
```

The following command builds the `pgtuned:11-2.5` image using `postgres:11` image **with PostGIS** `2.5` :

```
docker build --no-cache --build-arg POSTGRES_VERSION=11 --build-arg POSTGIS_VERSION=2.5 . -t pgtuned:11-2.5
```

➡️ A compatibility matrix between PostgreSQL and PostGIS versions is available [here](https://trac.osgeo.org/postgis/wiki/UsersWikiPostgreSQLPostGIS).

### Running PGTuned image

`POSTGRES_PASSWORD` environment variable is **compulsory** to use the official PostgreSQL image and therefore the `pgtuned` image.  
All other environment variables of the official PostgreSQL Docker image may also be used (`POSTGRES_USER`, `POSTGRES_DB`, ...).

In addition the following environment variables may be provided to tune PostgreSQL with `pgtune.sh` :
* `DB_TYPE` : If not provided `web` will be used as default `DB_TYPE`
* `TOTAL_MEM` : If not provided `pgtune.sh` will try to determine the total memory automatically
* `CPU_COUNT` : If not provided `pgtune.sh` will try to determine the cpu count automatically
* `MAX_CONN` : If not provided `200` wil be used as default maximum client connections number
* `STGE_TYPE` : If not provided `pgtune.sh` will try to determine the storage type automatically
* *`PG_VERSION` : Should not be necessary as Docker image `PG_MAJOR` environment variable will be used by default*

Default command line for running the `pgtuned` image with default `pgtune.sh` options :
```
docker run -d -e POSTGRES_PASSWORD=secret --name pgtuned pgtuned
```

Command line example for running the `pgtuned` image with `2GB` of RAM, `mixed` database type, `4` cpu cores and `ssd` storage :
```
docker run -d -e POSTGRES_PASSWORD=secret -e TOTAL_MEM=2GB -e DB_TYPE=mixed -e CPU_COUNT=4 -e STGE_TYPE=ssd --name pgtuned pgtuned
```

You can check PostgreSQL parameter (here `work_mem`) by using such a command once the `pgtuned` container is up and running :
```
user@machine:$ docker exec -ti pgtuned psql -U postgres -W -c "show work_mem;"
Password: 
 work_mem 
----------
 1310kB
(1 row)
```

You can also check the content of the `postgresql.conf` file generated by `pgtune.sh` by running :
```
user@machine:$ docker exec -ti pgtuned cat /var/lib/postgresql/data/postgresql.conf
# DB Version: 14
# OS Type: linux
# DB Type: web
# Total Memory (RAM): 3927732 kB
# CPUs num: 2
# Connections num: 200
# Data Storage: hdd

max_connections = 200
shared_buffers = 981933kB
effective_cache_size = 2945799kB
maintenance_work_mem = 245483kB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 4
effective_io_concurrency = 2
work_mem = 4909kB
min_wal_size = 1GB
max_wal_size = 4GB
max_worker_processes = 2
max_parallel_workers = 2
max_parallel_maintenance_workers = 1
max_parallel_workers_per_gather = 1
```

### Using PGTuned with docker-compose

A docker-compose file is provided to illustrate how to use the `pgtuned` image in the context of a docker-compose project.
