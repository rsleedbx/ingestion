#!/usr/bin/env bash

LOGNAME=$(logname 2>/dev/null)
LOGNAME=${LOGNAME:-root}

start_mysql() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o |  tr '[:upper:]' '[:lower:]' )}}
    case "${OS_TYPE,,}" in
    darwin)
        mysqld_safe --datadir=/opt/homebrew/var/mysql
        ;;
    gnu/linux)
        sudo systemctl restart mysql
        # on gcp, systemctl can't run and will exit with rc=1
        if [ "$?" != "0" ]; then
            sudo -u mysql mysqld_safe
        fi
        ;;
    *)
        echo "not supported"
        ;;
    esac
}

stop_mysql() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o |  tr '[:upper:]' '[:lower:]' )}}
    case "${OS_TYPE,,}" in
    darwin)
        pkill mysqld 
        ;;
    gnu/linux)
        sudo systemctl stop mysql
        # on gcp, systemctl can't run and will exit with rc=1
        if [ "$?" != "0" ]; then
            sudo pkill mysqld
        fi        
        ;;
    *)
        echo "not supported"
        ;;
    esac
}

install_mysql() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o |  tr '[:upper:]' '[:lower:]' )}}
    case "${OS_TYPE,,}" in
    darwin)
        brew list mysql@8.3 || brew install mysql@8.3
        ;;
    gnu/linux)
        # install mysql with wal2json plugin
        [ -z "$(dpkg -l mysql-server 2>/dev/null)" ] && sudo apt-get -y update && sudo apt-get -y install mysql-server 
        start_mysql
        sudo mysql -e "create database localhost;"
        ;;
    *)
        echo "not supported"
        ;;
    esac
}

mysql_cli() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o |  tr '[:upper:]' '[:lower:]' )}}
    local SRC_DB=${SRC_DB:-${LOGNAME:-arcsrc}}
    local SRCDB_HOST=${SRCDB_HOST:-localhost}
    local SRCDB_PORT=${SRCDB_PORT:-5432}
    local SRCDB_ARC_USER=${SRCDB_ARC_USER:-arcsrc}
    local SRCDB_ARC_PW=${SRCDB_ARC_PW:-Passw0rd}
    # when stdin is redirected
    if [ ! -t 0 ]; then
        local mysql_cli_batch_mode="--batch"
        cat <(printf "\n") - | \
        mysql -d "$SRCDB_DB" -h "$SRCDB_HOST" -p "$SRCDB_PORT" -U "${SRCDB_ARC_USER}" $mysql_cli_batch_mode "$@"
    else
        mysql -d "$SRCDB_DB" -h "$SRCDB_HOST" -p "$SRCDB_PORT" -U "${SRCDB_ARC_USER}" $mysql_cli_batch_mode "$@"
    fi
}

mysql_root_cli() {
    local OS_TYPE=${1:-${OS_TYPE:-$(uname -o |  tr '[:upper:]' '[:lower:]' )}}
    local SRCDB_HOST=${SRCDB_HOST:-localhost}
    local SRCDB_PORT=${SRCDB_PORT:-3306}
    local SRCDB_ROOT_USER=${SRCDB_ROOT_USER:-debian-sys-maint}
    local SRCDB_ROOT_PW=${SRCDB_ROOT_PW:-$(grep -m1 "^password" /etc/mysql/debian.cnf | awk -F'[ =]' '{print $NF}')}
    # when stdin is redirected
    if [ ! -t 0 ]; then
        local mysql_cli_batch_mode="--batch"
        mysql -h "$SRCDB_HOST" -P "$SRCDB_PORT" -u "${SRCDB_ROOT_USER}" -p${SRCDB_ROOT_PW} $mysql_cli_batch_mode "$@"
    else
        mysql -h "$SRCDB_HOST" -P "$SRCDB_PORT" -u "${SRCDB_ROOT_USER}" -p${SRCDB_ROOT_PW}$mysql_cli_batch_mode "$@"
    fi
}

create_user() {  
    local CFG_DIR=${CFG_DIR:-/tmp}
    local SRCDB_ARC_USER=${SRCDB_ARC_USER:-arcsrc} 
  if [ -n "$( echo "SELECT 1 FROM mysql.user WHERE user='${SRCDB_ARC_USER}';" | mysql_root_cli )" ]; then 
    echo "user ${SRCDB_ARC_USER} already exists.  skipping"
    return 0
  fi

  echo "creating user ${SRCDB_ARC_USER}"
  cat >$CFG_DIR/create_user.sql <<EOF
    CREATE USER arcsrc identified by 'Passw0rd';
    create database arcsrc;
    GRANT ALL ON arcsrc.* to 'arcsrc';
    -- replication grants cannot be limit to database.  has to be *.*    
    GRANT REPLICATION CLIENT ON *.* TO arcsrc;
    GRANT REPLICATION SLAVE ON *.* TO arcsrc;    
EOF

  cat $CFG_DIR/create_user.sql | mysql_root_cli
}

drop_user() {
    local CFG_DIR=${CFG_DIR:-/tmp}
    local SRCDB_ARC_USER=${SRCDB_ARC_USER:-arcsrc}     
    cat >$CFG_DIR/drop_user.sql <<EOF
drop database ${SRCDB_ARC_USER};
drop user ${SRCDB_ARC_USER};
EOF
    cat $CFG_DIR/drop_user.sql | mysql_root_cli
}

