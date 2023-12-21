#!/usr/bin/env bash

# Place ourselves in scripts directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR" || exit
# Get back to root level
cd ../../ || exit

# This scripts runs pgtune.sh and compare its results
# to expected results (see /expected_results directory).
# Requires cmp command installed

test_files_dir="test/expected_results/"
pgtuned_script="pgtune.sh"
pg_versions="17 16 15 14 13 12 11 10 9.6 9.5"
total_mem=8GB
cpu_counts="2 4" 
max_conn=1000
stge_types="ssd hdd san"
db_types="web oltp dw desktop mixed"

for cpu_count in $cpu_counts
do
  for pg_version in $pg_versions
  do
    for stge_type in $stge_types
    do
      for db_type in $db_types
      do
        if [ "$pg_version" = "9.5" -o "$pg_version" = "9.6" ]
        then
          db_type="web"
          cpu_count=8
        fi
        echo "TESTING WITH THE FOLLOWING PARAMETERS"
        echo "====================================="
        echo "= pg_version: $pg_version"
        echo "= db_type: $db_type"
        echo "= total_mem: $total_mem"
        echo "= cpu_count: $cpu_count"
        echo "= max_conn: $max_conn"
        echo "= stge_type: $stge_type"
        echo "====================================="
        output_file="$pg_version"_"$db_type"_"$total_mem"_"$cpu_count"_"$max_conn"_"$stge_type.txt"
        bash "$pgtuned_script" -v "$pg_version" -t "$db_type" -m "$total_mem" -u "$cpu_count" -c "$max_conn" -s "$stge_type" > "$output_file"
        test_file="$pg_version"_linux_"$db_type"_"$cpu_count"_"$total_mem"_"$max_conn"_"$stge_type".txt
        if [ ! -f "$test_files_dir$test_file" ]
        then
          echo "Test result : error"
          echo "REASON : $test_file does not exist"
          exit 2
        fi
        if [ "$(cmp "$test_files_dir$test_file" "$output_file")" ]
        then
          echo "Test result : error"
          echo "REASON : generated file does not match existing file. Inspect $output_file."
          exit 1
        else
          echo "Test result : passed"
          echo
        fi
        rm "$output_file"
      done
    done
  done
done