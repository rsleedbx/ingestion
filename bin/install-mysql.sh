#!/usr/bin/env bash

LOGNAME=$(logname 2>/dev/null)
LOGNAME=${LOGNAME:-root}

start_mysql() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o)}}
    case "${OS_TYPE,,}" in
    darwin)
        mysqld_safe --datadir=/opt/homebrew/var/mysql
        ;;
    linux)
        mysqld_safe
        ;;
    *)
        echo "not supported"
        ;;
    esac
}

stop_mysql() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o)}}
    case "${OS_TYPE,,}" in
    darwin)
        pkill mysqld 
        ;;
    linux)
        sudo pkill mysqld 
        ;;
    *)
        echo "not supported"
        ;;
    esac
}

install_mysql() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o)}}
    case "${OS_TYPE,,}" in
    darwin)
        brew list mysql@8.3 || brew install mysql@8.3
        ;;
    linux)
        # install mysql with wal2json plugin
        [ -z "$(dpkg -l mysql 2>/dev/null)" ] && sudo apt-get -y update && sudo apt-get -y install mysql 
        ;;
    *)
        echo "not supported"
        ;;
    esac
}

mysql_cli() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o)}}
    local SRC_DB=${SRC_DB:-${LOGNAME:-arcsrc}}
    local SRCDB_HOST=${SRCDB_HOST:-localhost}
    local SRCDB_PORT=${SRCDB_PORT:-5432}
    local SRCDB_ARC_USER=${SRCDB_ARC_USER:-arcsrc}
    local SRCDB_ARC_PW=${SRCDB_ARC_PW:-Passw0rd}
    # when stdin is redirected
    if [ ! -t 0 ]; then
        local mysql_cli_batch_mode="--csv"
        cat <(printf "\n") - | \
        mysql -d "$SRCDB_DB" -h "$SRCDB_HOST" -p "$SRCDB_PORT" -U "${SRCDB_ARC_USER}" $mysql_cli_batch_mode "$@"
    else
        mysql -d "$SRCDB_DB" -h "$SRCDB_HOST" -p "$SRCDB_PORT" -U "${SRCDB_ARC_USER}" $mysql_cli_batch_mode "$@"
    fi
}

mysql_root_cli() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o)}}
    local SRC_DB=${SRC_DB:-${LOGNAME:-arcsrc}}
    local SRCDB_HOST=${SRCDB_HOST:-localhost}
    local SRCDB_PORT=${SRCDB_PORT:-5432}
    local SRCDB_ROOT_USER=${SRCDB_ROOT_USER:-postgres}
    local SRCDB_ROOT_PW=${SRCDB_ARC_PW:-Passw0rd}
    # when stdin is redirected
    if [ ! -t 0 ]; then
        local mysql_cli_batch_mode="--csv"
        cat <(printf "\n") - | \
        psql -d "$SRCDB_DB" -h "$SRCDB_HOST" -p "$SRCDB_PORT" -U "${SRCDB_ROOT_USER}" $mysql_cli_batch_mode "$@"
    else
        psql -d "$SRCDB_DB" -h "$SRCDB_HOST" -p "$SRCDB_PORT" -U "${SRCDB_ROOT_USER}" $mysql_cli_batch_mode "$@"
    fi
}
