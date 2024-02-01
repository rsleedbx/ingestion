#!/usr/bin/env bash

# install 
#  https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-ubuntu?view=sql-server-ver16&tabs=ubuntu2004
# setup 
#   https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-configure-mssql-conf?view=sql-server-ver16
# start and stop 
#   https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-start-stop-restart-sql-server-services?view=sql-server-ver16&source=recommendations


if [ -z "$(dpkg -l mssql-server 2>/dev/null)" ]; then 

    curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
    sudo add-apt-repository -y "$(wget -qO- https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/mssql-server-2022.list)"
    sudo apt-get update -y 
    sudo apt-get install -y dialog mssql-server --fix-missing

    # TODO getting not found http://security.ubuntu.com/ubuntu/pool/main/g/glibc/libc6-dbg_2.35-0ubuntu3.5_amd64.deb

    curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
    curl https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list
    sudo apt-get update -y
    # this one has yes interaction
    sudo apt-get install -y mssql-tools18 unixodbc-dev

    sudo mkdir -p /var/opt/mssql
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
    sudo systemctl start mssql-server

    # below may not be required
    #sudo /opt/mssql/bin/mssql-conf set sqlagent.enabled true
    #sudo /opt/mssql/bin/mssql-conf setup
    #systemctl status mssql-server --no-pager
    #sudo systemctl stop mssql-server
fi

heredoc_file() {
    eval "$( echo -e '#!/usr/bin/env bash\ncat << EOF_EOF_EOF' | cat - $1 <(echo -e '\nEOF_EOF_EOF') )"    
}


export PATH=/opt/mssql-tools18/bin:$PATH
export MSSQL_SA_PASSWORD=Passw0rd
export DB_ARC_USER=arcsrc
export DB_ARC_PW=Passw0rd
export DB_DB=arcsrc
sqlcmd -S localhost -U sa -P "${MSSQL_SA_PASSWORD}" -C <<EOF
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
-- required for change tracking
ALTER DATABASE ${DB_DB}
SET CHANGE_TRACKING = ON  
(CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON) -- required for CDC
go
-- required for CDC
EXEC sys.sp_cdc_enable_db 
go
EOF


# create YCSB table
sqlcmd -S localhost -U arcsrc -P "${DB_ARC_PW}" -C <<EOF
CREATE TABLE YCSBSPARSE (
	YCSB_KEY INT,
	FIELD0 TEXT, FIELD1 TEXT,
	FIELD2 TEXT, FIELD3 TEXT,
	FIELD4 TEXT, FIELD5 TEXT,
	FIELD6 TEXT, FIELD7 TEXT,
	FIELD8 TEXT, FIELD9 TEXT,
	PRIMARY KEY (YCSB_KEY),
);
EOF

# show tables
sqlcmd -S localhost -U arcsrc -P "${DB_ARC_PW}" -C <<EOF
SELECT * FROM INFORMATION_SCHEMA.TABLES;
EOF