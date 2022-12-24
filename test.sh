#!/usr/bin/env bash

test_files_dir="test_files/"
pg_versions="15 14 13 12 11 10 9.6 9.5"
db_types="web oltp dw desktop mixed"
total_mem=8GB
cpu_count=8
max_conn=1000
stge_types="ssd hdd san"

for pg_version in $pg_versions
do
  for stge_type in $stge_types
  do
      db_type="web"
      echo "TESTING WITH THE FOLLOWING PARAMETERS"
      echo "====================================="
      echo "= pg_version: "$pg_version
      echo "= db_type: "$db_type
      echo "= total_mem: "$total_mem
      echo "= cpu_count: "$cpu_count
      echo "= max_conn: "$max_conn
      echo "= stge_type: "$stge_type
      echo "====================================="
      output_file=$pg_version$db_type$total_mem$cpu_count$max_conn$stge_type".txt"
      bash pgtune.sh -v $pg_version -t $db_type -m $total_mem -u $cpu_count -c $max_conn -s $stge_type > $output_file
      test_file=$pg_version"_linux_"$db_type"_"$total_mem"_"$cpu_count"_"$max_conn"_"$stge_type".txt"
      if [ ! -f "$test_files_dir$test_file" ]
      then
        echo "Test result : error"
        echo "REASON : $test_file does not exist"
        exit 2
      fi 
      if [ "$(cmp $test_files_dir$test_file $output_file)" ]
      then
        echo "Test result : error"
        echo "REASON : generated file does not match existing file. Inspect $output_file."
        exit 1
      else
        echo "Test result : passed"
        echo
      fi
      rm $output_file
  done
done
