#!/usr/bin/env bash

LOGNAME=$(logname 2>/dev/null)
LOGNAME=${LOGNAME:-root}

start_pg() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o |  tr '[:upper:]' '[:lower:]' )}}
    case "${OS_TYPE,,}" in
    darwin)
        pg_ctl restart --pgdata=/opt/homebrew/var/postgresql@14 --options "-c wal_level=logical -c max_replication_slots=10 -c max_connections=300 -c shared_buffers=80MB -c max_wal_size=3GB"
        ;;
    gnu/linux)
        pgver=$(dpkg-query --showformat='${Version}' --show postgresql | cut -d+ -f1)
        sudo pg_ctlcluster $pgver main restart --options "-c wal_level=logical -c max_replication_slots=10 -c max_connections=300 -c shared_buffers=80MB -c max_wal_size=3GB"
        ;;
    *)
        echo "not supported"
        ;;
    esac
}

stop_pg() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o |  tr '[:upper:]' '[:lower:]' )}}
    case "${OS_TYPE,,}" in
    darwin)
        pg_ctl stop --pgdata=/opt/homebrew/var/postgresql@14 
        ;;
    gnu/linux)
        pgver=$(dpkg-query --showformat='${Version}' --show postgresql | cut -d+ -f1)
        sudo pg_ctlcluster ${pgver} main stop 
        ;;
    *)
        echo "not supported"
        ;;
    esac
}

install_pg() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o |  tr '[:upper:]' '[:lower:]' )}}
    case "${OS_TYPE,,}" in
    darwin)
        brew list postgresql@14 || brew install postgresql@14
        brew list wal2json || brew install wal2json 
        createuser --superuser postgres
        ;;
    gnu/linux)
        # install pg with wal2json plugin
        [ -z "$(dpkg -l postgresql 2>/dev/null)" ] && sudo apt-get -y update && sudo apt-get -y install postgresql 

        sudo apt-get -y install postgresql-$(dpkg-query --showformat='${Version}' --show postgresql | cut -d+ -f1)-wal2json postgresql-contrib dialog
        # allow -U pgroot login 
        sudo -u postgres createuser -s -i -d -r -l -w pgroot
        sudo -u postgres psql -c "create database pgroot;"
        sudo -u postgres psql -c "alter database pgroot owner to pgroot;"
        sudo -u postgres psql -c "ALTER ROLE pgroot WITH PASSWORD 'Passw0rd';"
        ;;
    *)
        echo "${OS_TYPE,,} not supported"
        ;;
    esac
}

pg_cli() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o |  tr '[:upper:]' '[:lower:]' )}}
    local SRC_DB=${SRC_DB:-${LOGNAME:-arcsrc}}
    local SRCDB_HOST=${SRCDB_HOST:-localhost}
    local SRCDB_PORT=${SRCDB_PORT:-5432}
    local SRCDB_ARC_USER=${SRCDB_ARC_USER:-arcsrc}
    local SRCDB_ARC_PW=${SRCDB_ARC_PW:-Passw0rd}
    # when stdin is redirected
    export PGPASSWORD=${SRCDB_ARC_PW} 
    if [ ! -t 0 ]; then
        local pg_cli_batch_mode="--csv"
        psql -d "$SRCDB_DB" -h "$SRCDB_HOST" -p "$SRCDB_PORT" -U "${SRCDB_ARC_USER}" $pg_cli_batch_mode "$@"
    else
        psql -d "$SRCDB_DB" -h "$SRCDB_HOST" -p "$SRCDB_PORT" -U "${SRCDB_ARC_USER}" $pg_cli_batch_mode "$@"
    fi
}

pg_root_cli() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o |  tr '[:upper:]' '[:lower:]' )}}
    local SRC_ROOT_DB=${SRC_ROOT_DB:-pgroot}
    local SRCDB_HOST=${SRCDB_HOST:-localhost}
    local SRCDB_PORT=${SRCDB_PORT:-5432}
    local SRCDB_ROOT_USER=${SRCDB_ROOT_USER:-pgroot}
    local SRCDB_ROOT_PW=${SRCDB_ROOT_PW:-"Passw0rd"}
    # when stdin is redirected
    export PGPASSWORD=${SRCDB_ROOT_PW}
    if [ ! -t 0 ]; then
        local pg_cli_batch_mode="--csv --tuples-only"
        cat <(printf "\n") - | \
        psql -d "$SRC_ROOT_DB" -h "$SRCDB_HOST" -p "$SRCDB_PORT" -U "${SRCDB_ROOT_USER}" $pg_cli_batch_mode "$@"
    else
        psql -d "$SRC_ROOT_DB" -h "$SRCDB_HOST" -p "$SRCDB_PORT" -U "${SRCDB_ROOT_USER}" $pg_cli_batch_mode "$@"
    fi
}

create_user() {  
    local CFG_DIR=${CFG_DIR:-/tmp}
    local SRCDB_ARC_USER=${SRCDB_ARC_USER:-arcsrc} 
  if [ -n "$( echo "SELECT 1 FROM pg_roles WHERE rolname='${SRCDB_ARC_USER}';" | sql_root_cli )" ]; then 
    echo "user ${SRCDB_ARC_USER} already exists.  skipping"
    return 0
  fi

  echo "creating user ${SRCDB_ARC_USER}"
  cat >$CFG_DIR/create_user.sql <<EOF
    CREATE USER arcsrc PASSWORD 'Passw0rd';
    create database arcsrc;
    ALTER DATABASE arcsrc SET synchronous_commit TO off;
    alter user arcsrc replication;
    alter database arcsrc owner to arcsrc;
    grant all privileges on database arcsrc to arcsrc;
EOF

  cat >$CFG_DIR/create_w2j.sql <<EOF
SELECT 'init' FROM pg_create_logical_replication_slot('arcsrc_w2j', 'wal2json');
SELECT * from pg_replication_slots;
CREATE TABLE IF NOT EXISTS "REPLICATE_IO_CDC_HEARTBEAT"(
    TIMESTAMP BIGINT NOT NULL,
    PRIMARY KEY(TIMESTAMP)
);  
EOF

  cat $CFG_DIR/create_user.sql | pg_root_cli
  cat $CFG_DIR/create_w2j.sql | pg_root_cli
}

drop_user() {
    local CFG_DIR=${CFG_DIR:-/tmp}
    local SRCDB_ARC_USER=${SRCDB_ARC_USER:-arcsrc}     
    cat >$CFG_DIR/drop_user.sql <<EOF
drop database "${SRCDB_ARC_USER}";
drop role "${SRCDB_ARC_USER}";
EOF
    cat $CFG_DIR/drop_user.sql | pg_root_cli
}


bulk_load() {
    local LOG_DIR=${LOG_DIR:-/tmp}
    local y_fieldcount=${y_fieldcount:-10} 
    local y_fillstart=${y_fillstart:-0} 
    local y_fillend=${y_fillend:-9}
    local TABLE_INST_NAME=${TABLE_INST_NAME:-''}
    local y_tabletype=${y_tabletype:-sparse}

    local fieldnames=$(cat <(echo ycsb_key) <(seq 0 $(( $y_fieldcount - 1 )) | awk '{printf "FIELD%d\n",$0}') | paste -sd,)

    if [ ! -f "$datafile" ]; then echo "\$datafile=$datafile does not exist"; return 1; fi

    set -x
    cat $datafile | pg_cli -c "copy YCSB${y_tabletype^^}${TABLE_INST_NAME} ($fieldnames) from STDIN with (FORMAT csv);" | tee ${LOG_DIR}/03_${y_tabletype}table.log
    set +x
}
