#!/bin/bash
set -e

cmd_opts=""

if [ ! -z $PG_VERSION ]
then
  cmd_opts+=" -v "$PG_VERSION
else
  cmd_opts+=" -v "$PG_MAJOR
fi

if [ ! -z $DB_TYPE ]
then
  cmd_opts+=" -t "$DB_TYPE
fi

if [ ! -z $TOTAL_MEM ]
then
  cmd_opts+=" -m "$TOTAL_MEM
fi

if [ ! -z $CPU_COUNT ]
then
  cmd_opts+=" -u "$CPU_COUNT
fi

if [ ! -z $MAX_CONN ]
then
  cmd_opts+=" -c "$MAX_CONN
fi

if [ ! -z $STGE_TYPE ]
then
  cmd_opts+=" -s "$STGE_TYPE
fi

cd /tmp
echo "[pgtuned.sh] executing \"pgtune.sh$cmd_opts\""
bash pgtune.sh $cmd_opts > postgresql.conf
cp /tmp/postgresql.conf /var/lib/postgresql/data/postgresql.conf
echo "[pgtuned.sh] postgresql.conf has been successfully pgtuned"
