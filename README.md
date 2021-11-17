# PGTuned

PGTuned is a first try at building a Docker PostgreSQL image that includes basic performance tuning based on available ressources and contemplated use-case.  
This project includes a bash script equivalent of [PGTune](https://github.com/le0pard/pgtune)

## `pgtune.sh`

This script is a bash port of [PGTune](https://github.com/le0pard/pgtune).

```
Usage: pgtune.sh [-h] [-v PG_VERSION] [-t DB_TYPE] [-m TOTAL_MEM] [-u CPU_COUNT] [-c MAX_CONN] [-s STGE_TYPE]

This script is a bash port of PGTune (https://pgtune.leopard.in.ua).
It produces a postgresql.conf based on supplied parameters.

  -h                  display this help and exit
  -v PG_VERSION       (optional) PostgreSQL version
                      accepted values: 9.5, 9.6, 10, 11, 12, 13, 14
                      default value: 14
  -t DB_TYPE          (optional) For what type of application is PostgreSQL used
                      accepted values: web, oltp, dw, desktop, mixed
                      default value: web
  -m TOTAL_MEM        (optional) how much memory can PostgreSQL use
                      accepted values: integer with unit ("MB" or "GB") between 1 and 9999 and greater than 512MB
                      default value: script will try to determine the total memory and exit in case of failure
  -u CPU_COUNT        (optional) number of CPUs, which PostgreSQL can use
                      accepted values: integer between 1 and 9999
                      CPUs = threads per core * cores per socket * sockets
                      default value: script will try to determine the CPUs count and exit in case of failure
  -c MAX_CONN         (optional) Maximum number of PostgreSQL client connections
                      accepted values: integer between 20 and 9999
                      default value: preset corresponding to db_type
  -s STGE_TYPE        (optional) Type of data storage device used with PostgreSQL
                      accepted values: hdd, sdd, san
                      default value: script will try to determine the storage type (san not supported)
```

`test.sh` offers some basic testing of the script. 

## Docker image

The PGTuned image is built on top of the [official PostgreSQL Docker image](https://hub.docker.com/_/postgres). The default tag used is `14`.  
In practice `pgtuned.sh` script replaces at container startup the default `postgresql.conf` by a new one created with `pgtune.sh` using supplied options.

### Building pgtuned image

`docker build --no-cache . -t pgtuned`

### Running pgtuned image

`POSTGRES_PASSWORD` environment variable is required to use the PostgreSQL image. All other environment variables of the official PostgreSQL Docker image may also be used.

In addition the following environment variables may be provided for tuning :
* `PG_VERSION` : Should not be necessary as Docker image `PG_MAJOR` environment variable will be used by default
* `DB_TYPE` : If not provided `web` by default
* `TOTAL_MEM` : If not provided `pgtune.sh` will try to determine the total memory
* `CPU_COUNT` : If not provided `pgtune.sh` will try to determine the cpu count
* `MAX_CONN` : If not provided `200` for default DB_TYPE
* `STGE_TYPE` : If not provided `pgtune.sh` will try to determine the cpu count

Command line example for running the docker image :
`docker run -e POSTGRES_PASSWORD=mysecretpassword -e TOTAL_MEM=8GB -e DB_TYPE=mixed -e CPU_COUNT=4 -e STGE_TYPE=ssd pgtuned`

### docker-compose

A docker-compose file is provided to illustrate how to use the PGTUned image in the context of a docker-compose project.
