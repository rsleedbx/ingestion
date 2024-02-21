#!/usr/bin/env bash

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
    sudo apt-get install -y dialog mssql-server --fix-missing

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

if [ ! -f /var/opt/mssql/mssql.conf ]; then 
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
    echo "sqlserver installed and started"
else
    echo "sqlserver already started" 
fi
