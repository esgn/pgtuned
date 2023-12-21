#!/usr/bin/env bash

#######################################
# Constants definition
#######################################
KB=1024
MB=1048576
GB=1073741824
TB=1099511627776
TOTAL_MEM=0
CPU_NUM=0
STORAGE_TYPE=""
CONN_NUM=0
DB_TYPE=""
DB_VERSION=0

#######################################
# Display help message
#######################################
function show_help() {
cat << EOF
Usage: ${0##*/} [-h] [-v PG_VERSION] [-t DB_TYPE] [-m TOTAL_MEM] [-u CPU_COUNT] [-c MAX_CONN] [-s STGE_TYPE]

This script is a bash port of PGTune (https://pgtune.leopard.in.ua).
It produces a postgresql.conf file based on supplied parameters.

  -h                  display this help and exit
  -v PG_VERSION       (optional) PostgreSQL version
                      accepted values: 9.5, 9.6, 10, 11, 12, 13, 14, 15, 16, 17
                      default value: 17
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
                      default value: preset corresponding to DB_TYPE
  -s STGE_TYPE        (optional) Type of data storage device used with PostgreSQL
                      accepted values: hdd, ssd, san
                      default value: this script will try to determine the storage type (san not supported)
                      and use hdd value in case of failure.
EOF
}

#######################################
# Utility function to print a warning.
# Arguments:
#   Message to print as warning
#######################################
function _warn() {
  echo "[pgtune.sh] warning: $*" >&2
}

#######################################
# Utility function to print an error
# related to an input value
# Arguments:
#   Message to print as input error
#######################################
function _input_error() {
  echo "[pgtune.sh] input error: $*" >&2
  exit 1
}

###########################################
# Utility function to print error messages.
# Arguments:
#   Message to print as error
###########################################
function _error() {
  echo "[pgtune.sh] error: $*" >&2
  exit 2
}

################################################
# Get total RAM amount in kB from /proc/meminfo.
# Arguments:
#   None
# Outputs:
#   Total RAM in kB
################################################
function get_total_ram () {
  local -i total_ram
  total_ram=$(< /proc/meminfo grep -i 'memtotal' | grep -o '[[:digit:]]*')
  if [[ -z $total_ram ]] || [[ "$total_ram" -eq "0" ]]; then
    _error "Cannot detect total memory size, terminating script. Please supply -m TOTAL_MEM."
  fi
  echo "$total_ram"
}

##########################################
# Get CPU cores count using nproc command.
# Arguments:
#   None
# Outputs:
#   Number of CPU cores
##########################################
function get_cpu_count () {
  local -i cpu_count
  cpu_count=$(nproc --all)
  if [[ -z $cpu_count ]] || [[ "$cpu_count" -eq "0" ]]; then
    _error "Cannot detect CPU count, terminating script. Please supply -u CPU_COUNT."
  fi
  echo "$cpu_count"
}

####################################################
# Try and guess the disk type using findmnt command
# and information available in /sys/block.
# Could greatly be improved.
# Globals:
#   PGDATA: used
# Arguments:
#   None
# Outputs:
#   Type of disks : 'ssd' or 'hdd'
####################################################
function get_disk_type () {
  # PGDATA should always be defined in base postgres image
  # findmnt should also be installed by default
  local disk_name
  local disk_type_clue
  disk_name="$(basename "$(findmnt -v -n -o SOURCE --target "$PGDATA" 2>/dev/null)" 2>/dev/null)"
  disk_type_clue="$(cat /sys/block/"$disk_name"/queue/rotational 2>/dev/null)"
  case "$disk_type_clue" in
    "0")
      disk_type="ssd"
      ;;
    "1")
      disk_type="hdd"
      ;;
    *)
      _warn "Cannot detect disk type. 'hdd' type will be used as STGE_TYPE argument was not supplied."
      disk_type="hdd"
      ;;
  esac
  echo $disk_type
}

###############################################
# Set default config values depending
# on PostgreSQL version number.
# Globals:
#   DB_VERSION: used
#   max_worker_processes: modified
#   max_parallel_workers_per_gather: modified
#   max_parallel_workers: modified
###############################################
function set_db_default_values() {
  case "$DB_VERSION" in
    "9.5")
      #max_worker_processes=8
      ;;
    "9.6")
      #max_worker_processes=8
      max_parallel_workers_per_gather=0
      ;;
    "10" | "11" | "12" | "13" | "14" | "15" | "16" | "17")
      max_worker_processes=8
      max_parallel_workers_per_gather=2
      max_parallel_workers=8
      ;;
    *)
      _error "unknown PostgreSQL version, cannot continue"
      ;;
  esac
}

###################################
# Set shared_buffers config value.
# Globals:
#   DB_TYPE: used
#   TOTAL_MEM: used
#   shared_buffers: modified
###################################
function set_shared_buffers() {
  case "$DB_TYPE" in
    "web")
      shared_buffers=$(( TOTAL_MEM/4 ))
      ;;
    "oltp")
      shared_buffers=$(( TOTAL_MEM/4 ))
      ;;
    "dw")
      shared_buffers=$(( TOTAL_MEM/4 ))
      ;;
    "desktop")
      shared_buffers=$(( TOTAL_MEM/16 ))
      ;;
    "mixed")
      shared_buffers=$(( TOTAL_MEM/4 ))
      ;;
    *)
      _error "unknown DB_TYPE, cannot calculate shared_buffers"
      ;;
  esac
  # Ignoring windows specific case here
}

#############################################
# Set set_effective_cache_size config value.
# Globals:
#   DB_TYPE: used
#   TOTAL_MEM: used
#   effective_cache_size: modified
#############################################
function set_effective_cache_size() {
  case "$DB_TYPE" in
    "web")
      effective_cache_size=$(( TOTAL_MEM*3/4 ))
      ;;
    "oltp")
      effective_cache_size=$(( TOTAL_MEM*3/4 ))
      ;;
    "dw")
      effective_cache_size=$(( TOTAL_MEM*3/4 ))
      ;;
    "desktop")
      effective_cache_size=$(( TOTAL_MEM/4 ))
      ;;
    "mixed")
      effective_cache_size=$(( TOTAL_MEM*3/4 ))
      ;;
    *)
      _error "unknown DB_TYPE, cannot calculate effective_cache_size"
      ;;
  esac
}

#############################################
# Set set_maintenance_work_mem config value.
# Globals:
#   DB_TYPE: used
#   TOTAL_MEM: used
#   effective_cache_size: modified
#############################################
function set_maintenance_work_mem() {
  local mem_limit=$(( 2 * GB / KB ))
  case "$DB_TYPE" in
    "web")
      maintenance_work_mem=$(( TOTAL_MEM/16 ))
      ;;
    "oltp")
      maintenance_work_mem=$(( TOTAL_MEM/16 ))
      ;;
    "dw")
      maintenance_work_mem=$(( TOTAL_MEM/8 ))
      ;;
    "desktop")
      maintenance_work_mem=$(( TOTAL_MEM/16 ))
      ;;
    "mixed")
      maintenance_work_mem=$(( TOTAL_MEM/16 ))
      ;;
    *)
      _error "unknown DB_TYPE, cannot calculate maintenance_work_mem"
      ;;
  esac
  if [ "$maintenance_work_mem" -ge "$mem_limit" ]; then
    maintenance_work_mem=$mem_limit
    # Ignoring windows specific case here
  fi
}

#######################################
# Set checkpoint_segments, min_wal_size
# and max_wal_size config values.
# Globals:
#   DB_VERSION: used
#   DB_TYPE: used
#   checkpoint_segments: modified
#   min_wal_size: modified
#   max_wal_size: modified
#######################################
function set_checkpoint_segments() {
  if [ "${DB_VERSION%.*}" -le 9 ] && [ "${DB_VERSION//./}" -lt 95 ]; then
    case "$DB_TYPE" in
      "web")
        checkpoint_segments=32
        ;;
      "oltp")
        checkpoint_segments=64
        ;;
      "dw")
        checkpoint_segments=128
        ;;
      "desktop")
        checkpoint_segments=3
        ;;
      "mixed")
        checkpoint_segments=32
        ;;
      *)
        _error "unknown DB_TYPE, cannot calculate checkpoint_segments"
        ;;
    esac
  else
    case "$DB_TYPE" in
      "web")
        min_wal_size=$(( 1024 * MB / KB ))
        max_wal_size=$(( 4096 * MB / KB ))
        ;;
      "oltp")
        min_wal_size=$(( 2048 * MB / KB ))
        max_wal_size=$(( 8192 * MB / KB ))
        ;;
      "dw")
        min_wal_size=$(( 4096 * MB / KB ))
        max_wal_size=$(( 16384 * MB / KB ))
        ;;
      "desktop")
        min_wal_size=$(( 100 * MB / KB ))
        max_wal_size=$(( 2048 * MB / KB ))
        ;;
      "mixed")
        min_wal_size=$(( 1024 * MB / KB ))
        max_wal_size=$(( 4096 * MB / KB ))
        ;;
      *)
        _error "unknown DB_TYPE, cannot calculate min_wal_size"
        ;;
    esac
  fi
}

####################################################
# Set set_checkpoint_completion_target config value.
# Globals:
#   checkpoint_completion_target: modified
####################################################
function set_checkpoint_completion_target() {
  # based on https://github.com/postgres/postgres/commit/bbcc4eb2
  checkpoint_completion_target=0.9
}

#######################################
# Set set_wal_buffers config value.
# Globals:
#   shared_buffers: used
#   wal_buffers: modified
#######################################
function set_wal_buffers() {
  # Follow auto-tuning guideline for wal_buffers added in 9.1, where it's
  # set to 3% of shared_buffers up to a maximum of 16MB.
  wal_buffers=$(( 3 * shared_buffers / 100 ))
  local max_wal_buffers=$(( 16 * MB / KB ))
  if [ "$wal_buffers" -gt "$max_wal_buffers" ];then
    wal_buffers=$max_wal_buffers
  fi
  # It's nice if wal_buffers is an even 16MB if it's near that number. Since
  # that is a common case on Windows, where shared_buffers is clipped to 512MB,
  # round upwards in that situation
  local near_max_wal_buffers=$(( 14 * MB / KB ))
  if [ "$wal_buffers" -gt "$near_max_wal_buffers" ] && [ "$wal_buffers" -lt "$max_wal_buffers" ]; then
    wal_buffers=$max_wal_buffers
  fi
  # if less, than 32 kb, than set it to minimum
  if [ "$wal_buffers" -lt 32 ]; then
    wal_buffers=32
  fi
}

#################################################
# Set set_default_statistics_target config value.
# Globals:
#   DB_TYPE: used
#   default_statistics_target: modified
#################################################
function set_default_statistics_target() {
  case "$DB_TYPE" in
    "web")
      default_statistics_target=100
      ;;
    "oltp")
      default_statistics_target=100
      ;;
    "dw")
      default_statistics_target=500
      ;;
    "desktop")
      default_statistics_target=100
      ;;
    "mixed")
      default_statistics_target=100
      ;;
    *)
      _error "unknown DB_TYPE, cannot calculate default_statistics_target"
      ;;
  esac
}

########################################
# Set set_random_page_cost config value.
# Globals:
#   STORAGE_TYPE: used
#   random_page_cost: modified
########################################
function set_random_page_cost() {
  case "$STORAGE_TYPE" in
    "ssd")
      random_page_cost=1.1
      ;;
    "hdd")
      random_page_cost=4
      ;;
    "san")
      random_page_cost=1.1
      ;;
    *)
      _error "unknown STORAGE_TYPE, cannot calculate random_page_cost"
      ;;
  esac
}

############################################
# Set effective_io_concurrency config value.
# Globals:
#   STORAGE_TYPE: used
#   effective_io_concurrency: modified
############################################
function set_effective_io_concurrency() {
  case "$STORAGE_TYPE" in
    "ssd")
      effective_io_concurrency=200
      ;;
    "hdd")
      effective_io_concurrency=2
      ;;
    "san")
      effective_io_concurrency=300
      ;;
    *)
      _error "unknown STORAGE_TYPE, cannot calculate effective_io_concurrency"
      ;;
  esac
}

#############################################################
# Set max_worker_processes, max_parallel_workers_per_gather,
# workers_per_gather, maintenance_workers
# and max_parallel_maintenance_workers config values.
# These values are stored in a parallel_settings array.
# Globals:
#   CPU_NUM: used
#   DB_VERSION: used
#   DB_TYPE: used
#   max_worker_processes: modified
#   max_parallel_workers_per_gather: modified
#   workers_per_gather: modified
#   maintenance_workers: modified
#   max_parallel_maintenance_workers: modified
#   parallel_settings: modified
#############################################################
function set_parallel_settings() {
  declare -Ag parallel_settings
  declare -ag orders
  if [ "$CPU_NUM" -lt 2 ] || { [ "${DB_VERSION%.*}" -le 9 ] && [ "${DB_VERSION//./}" -lt 95 ]; }; then
    return 0
  fi
  if [ "${DB_VERSION%.*}" -ge 10 ] && [ "$CPU_NUM" -lt 4 ]; then
    return 0
  fi
  parallel_settings["max_worker_processes"]="$CPU_NUM"
  orders+=( "max_worker_processes" )
  if [ "${DB_VERSION//./}" -ge "96" ] || [ "${DB_VERSION%.*}" -ge 10 ]; then
    workers_per_gather=$(( CPU_NUM / 2 ))
    if [ $workers_per_gather -gt 4 ] && [[ "$DB_TYPE" != "dw" ]]; then
      workers_per_gather=4
    fi
    parallel_settings["max_parallel_workers_per_gather"]="$workers_per_gather"
    orders+=( "max_parallel_workers_per_gather" )
  fi
  if [ "${DB_VERSION%.*}" -ge 10 ]; then
    parallel_settings["max_parallel_workers"]="$CPU_NUM"
    orders+=( "max_parallel_workers" )
  fi
  if [ "${DB_VERSION%.*}" -ge 11 ]; then
    maintenance_workers=$(( CPU_NUM / 2 ))
    if [ $maintenance_workers -gt 4 ]; then
      maintenance_workers=4
    fi
    parallel_settings["max_parallel_maintenance_workers"]="$maintenance_workers"
    orders+=( "max_parallel_maintenance_workers" )
  fi
}

###########################################
# Set work_mem config value.
# Globals:
#   DB_TYPE: used
#   parallel_settings: used
#   max_parallel_workers_per_gather: used
#   TOTAL_MEM: used
#   shared_buffers: used
#   CONN_NUM: used
#   work_mem: modified
###########################################
function set_work_mem() {
  local -i parallel_for_work_mem=1
  if [ "${#parallel_settings[@]}" -gt "0" ]; then
    if [[ ${parallel_settings["max_worker_processes"]} ]]; then
      parallel_for_work_mem=${parallel_settings["max_worker_processes"]}
    fi
  elif [ -n "${max_worker_processes+x}" ]; then
    parallel_for_work_mem=$max_worker_processes
  fi
  work_mem_value=$(( (TOTAL_MEM - shared_buffers) / (( CONN_NUM + parallel_for_work_mem ) * 3) ))
  # Older calculation for 9.5 and 9.6
  if [ "${DB_VERSION%.*}" -le 9 ] && [ "${DB_VERSION//./}" -le 96 ]; then
    parallel_for_work_mem=1
    if [ "${#parallel_settings[@]}" -gt "0" ]; then
      if [[ ${parallel_settings["max_parallel_workers_per_gather"]} ]]; then
        parallel_for_work_mem=${parallel_settings["max_parallel_workers_per_gather"]}
      fi
    elif [ -n "${max_parallel_workers_per_gather+x}" ]; then
      parallel_for_work_mem=$max_parallel_workers_per_gather
    fi
    work_mem_value=$(( (TOTAL_MEM - shared_buffers) / (CONN_NUM * 3) / parallel_for_work_mem ))
  fi
  case "$DB_TYPE" in
    "web")
      work_mem=$work_mem_value
      ;;
    "oltp")
      work_mem=$work_mem_value
      ;;
    "dw")
      work_mem=$(( work_mem_value/2 ))
      ;;
    "desktop")
      work_mem=$(( work_mem_value/6 ))
      ;;
    "mixed")
      work_mem=$(( work_mem_value/2 ))
      ;;
    *)
      _error "unknown DB_TYPE, cannot calculate work_mem"
      ;;
  esac
  if [ $work_mem -lt 64 ]; then
    work_mem=64
  fi
}

#######################################
# Set huge pages
# Globals:
#   disk_type: used
#   huge_pages: modified
#######################################
function set_huge_pages() {
  if [[ "$TOTAL_MEM" -ge "$(( 32 * MB ))" ]]; then
    huge_pages="try"
  else
    huge_pages="off"
  fi
}

#############################################
# Format config option value
# Arguments:
#   Config value to be formatted
#   Number of spaces between value and unit
# Outputs:
#   Formated value
#############################################
function format_value() {
  # Set space value to 0 if the argument is missing
  with_space=${2:-0}
  if [[ $with_space -eq "1" ]]; then
    space=" "
  else
    space=""
  fi
  if [ $(( $1 % MB )) -eq 0 ]; then
    formatted_value=$(( $1 / MB ))$space"GB"
    echo "$formatted_value"
  elif [ $(( $1 % KB )) -eq 0 ]; then
    formatted_value=$(( $1 / KB ))$space"MB"
    echo "$formatted_value"
  else
    formatted_value=$1$space"kB"
    echo "$formatted_value"
  fi
}

#######################################
# Main method
#######################################
function main() {

  while getopts "hv:t:m:u:c:s:" opt; do
    case $opt in
      h)
        show_help
        exit 0
        ;;
      v)
        v=$OPTARG
        if [ "$v" != "9.5" ] && \
        [ "$v" != "9.6" ] && \
        [ "$v" != "10" ] && \
        [ "$v" != "11" ] && \
        [ "$v" != "12" ] && \
        [ "$v" != "13" ] && \
        [ "$v" != "14" ] && \
        [ "$v" != "15" ] && \
        [ "$v" != "16" ] && \
        [ "$v" != "17" ]; then
            _input_error "$v is not a valid PostgreSQL version number"
        fi
        DB_VERSION=$v
        ;;
      t)
        t=$OPTARG
        if [ "$t" != "web" ] && \
        [ "$t" != "oltp" ] && \
        [ "$t" != "dw" ] && \
        [ "$t" != "desktop" ] && \
        [ "$t" != "mixed" ]; then
            _input_error "$t is not a valid database type identifier"
        fi
        DB_TYPE="$t"
        ;;
      m)
        m=$OPTARG
        if [[ $m == *"MB"* ]]; then
            ram=${m%"MB"}
            if [ "$ram" -lt "512" ] || [ "$ram" -gt "9999" ]; then
              _input_error "total memory in MB must be greater than or equal to 512MB and less than or equal to 9999MB"
            fi
            ram=$(( ram*KB ))
        elif [[ $m == *"GB"* ]]; then
            ram=${m%"GB"}
            if [ "$ram" -lt "1" ] || [ "$ram" -gt "9999" ]; then
              _input_error "total memory in GB must be greater than or equal to 1GB and less than or equal to 9999GB"
            fi
            ram=$(( ram*MB ))
        else
            _input_error "$m does not contain a valid unit identifier (use MB or GB)"
        fi
        TOTAL_MEM="$ram"
        ;;
      u)
        u=$OPTARG
        if [ "$u" -lt "1" ] || [ "$u" -gt "9999" ]; then
          _input_error  "CPU count must be greater than or equal to 1 and less than or equal to 9999"
        fi
        CPU_NUM=$u
        ;;
      c)
        c=$OPTARG
        if [ "$c" -lt "20" ] || [ "$c" -gt "9999" ]; then
          _input_error "connections number must be greater than or equal to 1 and less than or equal to 9999"
        fi
        CONN_NUM=$c
        ;;
      s)
        s=$OPTARG
        if [ "$s" != "hdd" ] && \
        [ "$s" != "ssd" ] && \
        [ "$s" != "san" ]; then
          _input_error "$s is not a valid storage type identifier"
        fi
        STORAGE_TYPE="$s"
        ;;
      *)
        show_help >&2
        exit 2
        ;;
    esac
  done

  # Set default values if not set
  
  if [ "${DB_VERSION//./}" -eq "0" ]; then
    DB_VERSION=17
  fi

  if [ "$TOTAL_MEM" -eq "0" ]; then
    TOTAL_MEM=$(get_total_ram) || exit $?
  fi

  if [ "$CPU_NUM" -eq "0" ]; then
    CPU_NUM=$(get_cpu_count) || exit $?
  fi

  if [ -z "$DB_TYPE" ]; then
    DB_TYPE="web"
  fi

  # get_disk_type returns hdd as default value if disk detection failed
  if [ -z "$STORAGE_TYPE" ]; then
    STORAGE_TYPE=$(get_disk_type)
  fi

  if [ "$CONN_NUM" -eq "0" ]; then
    case $DB_TYPE in
      "web")
        CONN_NUM=200
        ;;
      "oltp")
        CONN_NUM=300
        ;;
      "dw")
        CONN_NUM=40
        ;;
      "desktop")
        CONN_NUM=20
        ;;
      "mixed")
        CONN_NUM=100
        ;;
      *) 
        CONN_NUM=20 # should never happen
        _error "unknown DB_TYPE, cannot calculate connections number"
        ;;
    esac
  fi

  readonly DB_VERSION
  readonly TOTAL_MEM
  readonly CPU_NUM
  readonly DB_TYPE
  readonly STORAGE_TYPE
  readonly DB_VERSION
  readonly CONN_NUM

  set_db_default_values || exit $?
  set_shared_buffers || exit $?
  set_effective_cache_size || exit $?
  set_maintenance_work_mem || exit $?
  set_checkpoint_segments || exit $?
  set_checkpoint_completion_target
  set_wal_buffers
  set_default_statistics_target || exit $?
  set_random_page_cost || exit $?
  set_effective_io_concurrency || exit $?
  set_parallel_settings
  set_work_mem || exit $?
  set_huge_pages

  echo "# DB Version: $DB_VERSION"
  echo "# OS Type: linux"
  echo "# DB Type: $DB_TYPE"
  echo "# Total Memory (RAM): $(format_value "$TOTAL_MEM" 1)"
  echo "# CPUs num: $CPU_NUM"
  echo "# Connections num: $CONN_NUM"
  echo "# Data Storage: $STORAGE_TYPE"
  echo
  echo "max_connections = $CONN_NUM"
  echo "shared_buffers = $(format_value $shared_buffers)"
  echo "effective_cache_size = $(format_value $effective_cache_size)"
  echo "maintenance_work_mem = $(format_value $maintenance_work_mem)"
  echo "checkpoint_completion_target = $checkpoint_completion_target"
  echo "wal_buffers = $(format_value $wal_buffers)"
  echo "default_statistics_target = $default_statistics_target"
  echo "random_page_cost = $random_page_cost"
  echo "effective_io_concurrency = $effective_io_concurrency"
  echo "work_mem = $(format_value $work_mem)"
  echo "huge_pages = $huge_pages"
  echo "min_wal_size = $(format_value $min_wal_size)"
  echo "max_wal_size = $(format_value $max_wal_size)"

  for key in "${orders[@]}"; do
    echo "$key = ${parallel_settings["$key"]}"
  done
  if [ -n "${checkpoint_segments+x}" ]; then
    echo "checkpoint_segments = $checkpoint_segments"
  fi

  unset set_parallel_settings
}

main "$@"
