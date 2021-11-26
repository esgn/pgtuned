ARG POSTGRES_VERSION=14

FROM postgres:${POSTGRES_VERSION}

ARG POSTGIS_VERSION=

ENV DB_TYPE=
ENV PG_VERSION=
ENV TOTAL_MEM=
ENV CPU_COUNT=
ENV MAX_CONN=
ENV STGE_TYPE=

# PostGIS install if required
RUN if [ ! -z $POSTGIS_VERSION ]; \
 then apt-get update \
 && apt-get install -y postgresql-${PG_MAJOR}-postgis-${POSTGIS_VERSION} \
 && apt-get install -y postgresql-${PG_MAJOR}-postgis-${POSTGIS_VERSION}-scripts \
 && apt-get install -y postgresql-${PG_MAJOR}-pgrouting \
 && apt-get install -y --no-install-recommends postgis \
 && rm -rf /var/lib/apt/lists/*; \
 fi

# Run the rest of the commands as the ``postgres``
USER postgres:postgres

# Scripts pgtuning
COPY pgtune.sh /tmp
COPY pgtuned.sh /docker-entrypoint-initdb.d
