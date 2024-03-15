#!/usr/bin/env bash

LOGNAME=$(logname 2>/dev/null)
LOGNAME=${LOGNAME:-root}

start_pg() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o)}}
    case "${OS_TYPE,,}" in
    darwin)
        pg_ctl restart --pgdata=/opt/homebrew/var/postgresql@14 --options "-c wal_level=logical -c max_replication_slots=10 -c max_connections=300 -c shared_buffers=80MB -c max_wal_size=3GB"
        ;;
    linux)
        sudo pg_ctlcluster $(dpkg-query --showformat='${Version}' --show postgresql | cut -d+ -f1) main restart --options "-c wal_level=logical -c max_replication_slots=10 -c max_connections=300 -c shared_buffers=80MB -c max_wal_size=3GB"
        ;;
    *)
        echo "not supported"
        ;;
    esac
}

stop_pg() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o)}}
    case "${OS_TYPE,,}" in
    darwin)
        pg_ctl stop --pgdata=/opt/homebrew/var/postgresql@14 
        ;;
    linux)
        sudo pg_ctlcluster stop 
        ;;
    *)
        echo "not supported"
        ;;
    esac
}

install_pg() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o)}}
    case "${OS_TYPE,,}" in
    darwin)
        brew list postgresql@14 || brew install postgresql@14
        brew list wal2json || brew install wal2json 
        createuser --superuser postgres
        ;;
    linux)
        # install pg with wal2json plugin
        [ -z "$(dpkg -l postgresql 2>/dev/null)" ] && sudo apt-get -y update && sudo apt-get -y install postgresql 

        sudo apt-get -y install postgresql-$(dpkg-query --showformat='${Version}' --show postgresql | cut -d+ -f1)-wal2json postgresql-contrib dialog
        ;;
    *)
        echo "not supported"
        ;;
    esac
}

pg_cli() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o)}}
    local SRC_DB=${SRC_DB:-${LOGNAME:-arcsrc}}
    local SRCDB_HOST=${SRCDB_HOST:-localhost}
    local SRCDB_PORT=${SRCDB_PORT:-5432}
    local SRCDB_ARC_USER=${SRCDB_ARC_USER:-arcsrc}
    local SRCDB_ARC_PW=${SRCDB_ARC_PW:-Passw0rd}
    # when stdin is redirected
    export PGPASSWORD=${SRCDB_ARC_PW} 
    if [ ! -t 0 ]; then
        local pg_cli_batch_mode="--csv"
        cat <(printf "\n") - | \
        psql -d "$SRCDB_DB" -h "$SRCDB_HOST" -p "$SRCDB_PORT" -U "${SRCDB_ARC_USER}" $pg_cli_batch_mode "$@"
    else
        psql -d "$SRCDB_DB" -h "$SRCDB_HOST" -p "$SRCDB_PORT" -U "${SRCDB_ARC_USER}" $pg_cli_batch_mode "$@"
    fi
}

pg_root_cli() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o)}}
    local SRC_DB=${SRC_DB:-${LOGNAME:-arcsrc}}
    local SRCDB_HOST=${SRCDB_HOST:-localhost}
    local SRCDB_PORT=${SRCDB_PORT:-5432}
    local SRCDB_ROOT_USER=${SRCDB_ROOT_USER:-postgres}
    local SRCDB_ROOT_PW=${SRCDB_ARC_PW:-Passw0rd}
    # when stdin is redirected
    if [ ! -t 0 ]; then
        local pg_cli_batch_mode="--csv"
        cat <(printf "\n") - | \
        psql -d "$SRCDB_DB" -h "$SRCDB_HOST" -p "$SRCDB_PORT" -U "${SRCDB_ROOT_USER}" $pg_cli_batch_mode "$@"
    else
        psql -d "$SRCDB_DB" -h "$SRCDB_HOST" -p "$SRCDB_PORT" -U "${SRCDB_ROOT_USER}" $pg_cli_batch_mode "$@"
    fi
}
