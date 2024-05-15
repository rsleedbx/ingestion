#!/usr/bin/env bash

LOGNAME=$(logname 2>/dev/null)
LOGNAME=${LOGNAME:-root}

start_sqlserver() {
    sudo systemctl restart mssql-server
    # on gcp, systemctl can't run and will exit with rc=1
    if [ "$?" != "0" ]; then
            sudo -b -n -u mssql /opt/mssql/bin/sqlservr "$@" >/dev/null
    fi

    if [ "$?" = 0 ]; then 
        echo "sqlserver started."
    else
        echo "sqlserver start failed. $?"
    fi
}

stop_sqlserver() {
    sudo systemctl stop mssql-server
    # on gcp, systemctl can't run and will exit with rc=1
    if [ "$?" != "0" ]; then
        sudo pkill sqlservr
    fi
    
    if [ "$?" = 0 ]; then 
        echo "sqlserver killed."
    else
        echo "sqlserver kill failed. $?"
    fi    
}

sql_cli() {
    local DB_DB=${DB_DB:-arcsrc}
    local DB_HOST=${DB_HOST:-localhost}
    local DB_PORT=${DB_PORT:-1433}
    local DB_ARC_USER=${DB_ARC_USER:-arcsrc}
    local DB_ARC_PW=${DB_ARC_PW:-Passw0rd}

  if [ -z "$(command -v sqlcmd)" ]; then export PATH=/opt/mssql-tools18/bin:$PATH; fi
  # when stdin is redirected
  # -I enable quite identified
  # -h-1 remove header and -----
  # -W remove trailing spaces
  # -s ","
  # -w width of the screen
  if [ ! -t 0 ]; then
    local sql_cli_batch_mode="-h-1 -W -s , -w 1024"
    cat <(printf "set NOCOUNT ON;\ngo\n") - | \
    sqlcmd -I -d "$DB_DB" -S "$DB_HOST,$DB_PORT" -U "${DB_ARC_USER}" -P "${DB_ARC_PW}" -C $sql_cli_batch_mode "$@"
  else
    sqlcmd -I -d "$DB_DB" -S "$DB_HOST,$DB_PORT" -U "${DB_ARC_USER}" -P "${DB_ARC_PW}" -C $sql_cli_batch_mode "$@"
  fi
}

sql_root_cli() {
    local DB_DB=${DB_DB:-master}
    local DB_HOST=${DB_HOST:-localhost}
    local DB_PORT=${DB_PORT:-1433}
    local DB_ROOT_USER=${DB_ARC_USER:-sa}
    local DB_ROOT_USER=${DB_ARC_PW:-Passw0rd}
    
  if [ -z "$(command -v sqlcmd)" ]; then export PATH=/opt/mssql-tools18/bin:$PATH; fi
  # when stdin is redirected
  # -I enable quite identified
  # -h-1 remove header and -----
  # -W remove trailing spaces
  # -s ","
  # -w width of the screen
  if [ ! -t 0 ]; then
    local sql_cli_batch_mode="-h-1 -W -s , -w 1024"
    cat <(printf "set NOCOUNT ON;\ngo\n") - | \
    sqlcmd -I -S "$DB_HOST,$DB_PORT" -U "${DB_ROOT_USER}" -P "${DB_ROOT_PW}" -C $sql_cli_batch_mode "$@"
  else
    sqlcmd -I -S "$DB_HOST,$DB_PORT" -U "${DB_ROOT_USER}" -P "${DB_ROOT_PW}" -C $sql_cli_batch_mode "$@"
  fi
}

add_user() {
    local DB_DB=${DB_DB:-arcsrc}
    local DB_HOST=${DB_HOST:-localhost}
    local DB_PORT=${DB_PORT:-1433}
    local DB_ARC_USER=${DB_ARC_USER:-arcsrc}
    local DB_ARC_PW=${DB_ARC_PW:-Passw0rd}
    cat <<EOF | sql_root_cli
CREATE LOGIN ${DB_ARC_USER} WITH PASSWORD = '${DB_ARC_PW}'
go

create database ${DB_DB}
go

use ${DB_DB}
go

CREATE USER ${DB_ARC_USER} FOR LOGIN ${DB_ARC_USER} WITH DEFAULT_SCHEMA=dbo
go

ALTER ROLE db_owner ADD MEMBER ${DB_ARC_USER}
go

ALTER ROLE db_ddladmin ADD MEMBER ${DB_ARC_USER}
go

alter user ${DB_ARC_USER} with default_schema=dbo
go

ALTER LOGIN ${DB_ARC_USER} WITH DEFAULT_DATABASE=[${DB_DB}]
go
EOF
}

# wait for db to be up
ping_sql_cli() {
  local -i max_wait=${1:-10}
  local -i count=0
  local -i rc=1
  while (( (rc != 0) && (count < max_wait) )); do
    echo "select 1;" | sql_root_cli > /dev/null
    rc=${PIPESTATUS[1]}
    if (( rc == 0 )); then 
      break
    else
      count=$(( count + 1 ))
      echo "$count: waiting for db"
      sleep 1
    fi 
  done
  return $rc
}


# install 
#  https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-ubuntu?view=sql-server-ver16&tabs=ubuntu2004
# setup 
#   https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-configure-mssql-conf?view=sql-server-ver16
# start and stop 
#   https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-start-stop-restart-sql-server-services?view=sql-server-ver16&source=recommendations

if [ -z "$(dpkg -l apt-utils 2>/dev/null)" ]; then 
    echo "installing apt-utils"    
    sudo apt-get install -y apt-utils
else
    echo "apt-utils already installed"    
fi

if [ -z "$(dpkg -l mssql-server 2>/dev/null)" ]; then 

    echo "installing mssql-server"
    curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
    sudo add-apt-repository -y "$(wget -qO- https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/mssql-server-2022.list)"
    sudo apt-get update -y 
    sudo apt-get install -y dialog 

    # use local repo if specified
    if [ -n "$SQL_SERVER_DPKG" ] && [ -d "$SQL_SERVER_DPKG" ]; then
        sudo dpkg -i $SQL_SERVER_DPKG/mssql-server_*.deb
    else
        sudo apt-get install -y mssql-server --fix-missing
    fi

    # TODO getting not found http://security.ubuntu.com/ubuntu/pool/main/g/glibc/libc6-dbg_2.35-0ubuntu3.5_amd64.deb

    curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
    curl https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list
    sudo apt-get update -y
    sudo chmod a+x /var/opt/mssql
else
    echo "mssql-server already installed"
fi

if [ -z "$(dpkg -l mssql-tools18 2>/dev/null)" ]; then 
    echo "installing mssql-tools18"    
    # this one has yes interaction
    sudo ACCEPT_EULA=Y apt-get install -y mssql-tools18
else
    echo "mssql-tools18 already installed"    
fi

if [ -z "$(dpkg -l unixodbc-dev 2>/dev/null)" ]; then 
    echo "installing unixodbc-dev"    
    # this one has yes interaction
    sudo ACCEPT_EULA=Y apt-get install -y unixodbc-dev
else
    echo "unixodbc-dev alrady installed"    
fi

if [ ! -f /var/opt/mssql/mssql.demo ]; then 
    sudo touch /var/opt/mssql/mssql.demo
    cat <<EOF | sudo tee /var/opt/mssql/mssql.conf 
    [sqlagent]
    enabled = true

    [licensing]
    azurebilling = false

    [EULA]
    accepteula = Y

    [telemetry]
    customerfeedback = false
EOF
    sudo MSSQL_SA_PASSWORD=Passw0rd /opt/mssql/bin/mssql-conf set-sa-password
    start_sqlserver "$@"
else
    echo "sqlserver already started" 
fi

PATH=
