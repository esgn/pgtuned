# PGTuned ![ci-status](https://github.com/esgn/pgtuned/actions/workflows/docker-image.yml/badge.svg) [![stability-alpha](https://img.shields.io/badge/stability-alpha-f4d03f.svg)](https://github.com/mkenney/software-guides/blob/master/STABILITY-BADGES.md#alpha)

PGTuned is a first attempt at building Docker PostgreSQL/PostGIS images which include basic performance tuning based on available resources and contemplated use-case.  

This project includes a bash script equivalent of [PGTune](https://github.com/le0pard/pgtune).

## `pgtune.sh`

This `pgtune.sh` script is a bash port of [PGTune](https://github.com/le0pard/pgtune).  
All arguments have been rendered optional. The script will either use default value or try and automatically determine the parameter value.

```
Usage: pgtune.sh [-h] [-v PG_VERSION] [-t DB_TYPE] [-m TOTAL_MEM] [-u CPU_COUNT] [-c MAX_CONN] [-s STGE_TYPE]

This script is a bash port of PGTune (https://pgtune.leopard.in.ua).
It produces a postgresql.conf file based on supplied parameters.

  -h                  display this help and exit
  -v PG_VERSION       (optional) PostgreSQL version
                      accepted values: 9.5, 9.6, 10, 11, 12, 13, 14, 15
                      default value: 15
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

The `test.sh` compares a selected number of `pgtune.sh` results with pre-generated `postgresql.conf` available in `test_files/`.  
<br />

## Building and running PGTuned Docker image

The PGTuned image is built on top of the [official PostgreSQL Docker image](https://hub.docker.com/_/postgres). The installation of [PostGIS](https://postgis.net/) is optional at building stage.  

When running the PGTuned image as a container, the `pgtuned.sh` script replaces on startup the default `postgresql.conf` file by a new one created with `pgtune.sh` using supplied parameters.

### Building PGTuned image

The build stage of the PGTuned image accepts **two optional build arguments** :
* `POSTGRES_VERSION` corresponds to any tag available in the [official PostgreSQL Docker image](https://hub.docker.com/_/postgres) save the `alpine` tags (examples : 14, 13.6, 11.15-stretch, ...). If omitted the `14` tag will be used.
* `POSTGIS_VERSION` corresponds to the version of [PostGIS](https://postgis.net/) that will be installed. The selected version of PostGIS must be available in the packages of the chosen PostgreSQL image. If omitted PostGIS will not be installed.  
<br />

Below are command line examples to build different version of the PGTuned image :

* Build the `pgtuned` image using `postgres:15` image **without PostGIS** :

```
docker build --no-cache . -t pgtuned
```

* Build the `pgtuned:13` image using `postgres:13` image **without PostGIS** :

```
docker build --no-cache --build-arg POSTGRES_VERSION=13 . -t pgtuned:13
```

* Build the `pgtuned:11-2.5` image using `postgres:11` image **with PostGIS** `2.5` :

```
docker build --no-cache --build-arg POSTGRES_VERSION=11 --build-arg POSTGIS_VERSION=2.5 . -t pgtuned:11-2.5
```

:point_right: The helper script `test/scripts/check-compatibility.sh` runs the main versions of the official Docker PostgreSQL image and checks available PostGIS versions for each. This could be used as a guide to select the correct version of PostGIS for each PostgreSQL image version. Note that a patch is applied for `postgres` images older than 12 still running on Debian Stretch.

<details> 
<summary>View ouput of <code>check-compatibility.sh</code></summary>
<pre>
<code>
Examining postgres:15
######################
Available PostGIS versions : 3
Running on Debian GNU/Linux 11 (bullseye)
<br/>
Examining postgres:14
######################
Available PostGIS versions : 3
Running on Debian GNU/Linux 11 (bullseye)
<br/>
Examining postgres:13
######################
Available PostGIS versions : 3
Running on Debian GNU/Linux 11 (bullseye)
<br/>
Examining postgres:12
######################
Available PostGIS versions : 3
Running on Debian GNU/Linux 11 (bullseye)
<br/>
Examining postgres:11
######################
applying apt-archive.postgres.org patch
Available PostGIS versions : 2.5 3
Running on Debian GNU/Linux 9 (stretch)
<br/>
Examining postgres:10
######################
applying apt-archive.postgres.org patch
Available PostGIS versions : 2.4 2.5 3
Running on Debian GNU/Linux 9 (stretch)
<br/>
Examining postgres:9.6
######################
applying apt-archive.postgres.org patch
Available PostGIS versions : 2.3 2.4 2.5 3
Running on Debian GNU/Linux 9 (stretch)
<br/>
Examining postgres:9.5
######################
applying apt-archive.postgres.org patch
Available PostGIS versions : 2.3 2.4 2.5 3
Running on Debian GNU/Linux 9 (stretch)
</code>
</pre>
</details>

### Running PGTuned image

`POSTGRES_PASSWORD` environment variable is **compulsory** to run the official PostgreSQL image and therefore the PGTuned image.  
All other environment variables of the official PostgreSQL Docker image may also be used (`POSTGRES_USER`, `POSTGRES_DB`, ...).

In addition, the following environment variables may be provided to tune PostgreSQL with `pgtune.sh` :
* `DB_TYPE` : If not provided `web` will be used as default `DB_TYPE`
* `TOTAL_MEM` : If not provided `pgtune.sh` will try to determine the total memory automatically
* `CPU_COUNT` : If not provided `pgtune.sh` will try to determine the cpu count automatically
* `MAX_CONN` : If not provided `200` wil be used as default maximum client connections number
* `STGE_TYPE` : If not provided `pgtune.sh` will try to determine the storage type automatically
* *`PG_VERSION` : Should not be necessary as Docker image `PG_MAJOR` environment variable will be used by default*

Default command line for running the PGTuned image with default `pgtune.sh` options :
```
docker run -d -e POSTGRES_PASSWORD=secret --name pgtuned pgtuned
```

Command line example for running the PGTuned image with `2GB` of RAM, `mixed` database type, `4` cpu cores and `ssd` storage :
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
... more lines displayed after this ...
```

### Using PGTuned images directly from Docker hub

This project builds a number of versions of the PGTuned image and deploy them to [Docker Hub](https://hub.docker.com/r/esgn/pgtuned) using the following tags :
* `latest` corresponds to PostgreSQL 15
* `postgis-latest` corresponds to PostgreSQL 15 and PostGIS 3
* `POSTGRES_VERSION` corresponds to a specific PostgreSQL image version (e.g. 12) without PostGIS
* `POSTGRES_VERSION-POSTGIS_VERSION` corresponds to a specific PostgreSQL image version including a specific PostGIS version (e.g. 12-3)

To use these images simply `docker pull esgn/pgtuned:tag` and run.

### Using PGTuned with docker-compose

A docker-compose file is provided to illustrate how to use the `pgtuned` image in the context of a docker-compose project.
