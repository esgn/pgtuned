#!/bin/bash
set -e

declare -A tuned
declare -A outoftune

cmd_opts=""

if [ -n "$PG_VERSION" ]
then
  cmd_opts+=" -v "$PG_VERSION
else
  cmd_opts+=" -v "$PG_MAJOR
fi

if [ -n "$DB_TYPE" ]
then
  cmd_opts+=" -t "$DB_TYPE
fi

if [ -n "$TOTAL_MEM" ]
then
  cmd_opts+=" -m "$TOTAL_MEM
fi

if [ -n "$CPU_COUNT" ]
then
  cmd_opts+=" -u "$CPU_COUNT
fi

if [ -n "$MAX_CONN" ]
then
  cmd_opts+=" -c "$MAX_CONN
fi

if [ -n "$STGE_TYPE" ]
then
  cmd_opts+=" -s "$STGE_TYPE
fi

cd /tmp

echo "[pgtuned.sh] executing \"pgtune.sh$cmd_opts\""
bash pgtune.sh $cmd_opts > tuned.conf

echo "[pgtuned.sh] importing additional parameters from existing postgresql.conf"
while IFS= read -r line; do
  if [[ $line =~ ^[[:blank:]]*([^\#]*)\ =\ ([^[[:blank:]]\#\'\"]*|\'.*\'|\".*\")[[:blank:]]*(\#?.*)$ ]]; then
    key=${BASH_REMATCH[1]}
    value=${BASH_REMATCH[2]}
    outoftune[$key]=$value
  fi
done < /var/lib/postgresql/data/postgresql.conf

while IFS= read -r line; do
  if [[ $line =~ ^([^\#]*)\ =\ (.*)$ ]]; then
    key=${BASH_REMATCH[1]}
    value=${BASH_REMATCH[2]}
    tuned[$key]=$value
  fi
done < tuned.conf

comment_line=0
for key in "${!outoftune[@]}"
do
  if [ ! "${tuned[$key]}" ]; then
    if [ "$comment_line" -eq 0 ]; then
      { echo; echo "# Configuration parameters harvested from original docker postgres image postgresql.conf"; echo; } >> tuned.conf
      comment_line=1
    fi
    echo "$key = ${outoftune[$key]}" >> tuned.conf
  fi
done

cp /tmp/tuned.conf /var/lib/postgresql/data/postgresql.conf
echo "[pgtuned.sh] postgresql.conf has been successfully pgtuned"
