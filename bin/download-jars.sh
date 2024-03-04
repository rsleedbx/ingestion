#!/usr/bin/env bash

LOGNAME=$(logname 2>/dev/null)
LOGNAME=${LOGNAME:-root}

if [ ! -d /opt/stage/libs ]; then
    sudo mkdir -p /opt/stage/libs && chown "${LOGNAME}" /opt/stage/libs
fi

# deltalake
if [ ! -f /opt/stage/libs/SparkJDBC42.jar ]; then
    pushd /opt/stage/libs >/dev/null
    wget -q https://databricks-bi-artifacts.s3.us-east-2.amazonaws.com/simbaspark-drivers/jdbc/2.6.22/SimbaSparkJDBC42-2.6.22.1040.zip
    unzip -q SimbaSparkJDBC42-2.6.22.1040.zip
    rm SimbaSparkJDBC42-2.6.22.1040.zip
    rm -rf docs EULA.txt 2>/dev/null
    popd >/dev/null
    echo "deltalake /opt/stage/libs/SparkJDBC42.jar downloaded"
else
    echo "deltalake /opt/stage/libs/SparkJDBC42.jar found"
fi

# lakehouse (unity catalog)
if [ ! -f /opt/stage/libs/DatabricksJDBC42.jar ]; then
    pushd /opt/stage/libs >/dev/null
    wget -q https://repo1.maven.org/maven2/com/databricks/databricks-jdbc/2.6.34/databricks-jdbc-2.6.34.jar
    mv databricks-jdbc-2.6.34.jar DatabricksJDBC42.jar
    rm -rf docs EULA.txt 2>/dev/null
    popd >/dev/null
    echo "lakehouse  /opt/stage/libs/DatabricksJDBC42.jar downloaded"
else
    echo "lakehouse  /opt/stage/libs/DatabricksJDBC42.jar found"
fi

# postgres
if [ ! -f /opt/stage/libs/postgresql-42.7.1.jar ]; then
    pushd /opt/stage/libs >/dev/null
    wget -q https://jdbc.postgresql.org/download/postgresql-42.7.1.jar
    popd >/dev/null
    echo "postgres  /opt/stage/libs/postgresql-42.7.1.jar downloaded"
else
    echo "postgres  /opt/stage/libs/postgresql-42.7.1.jar found"
fi

# mariadb
if [ ! -f /opt/stage/libs/mariadb-java-client-3.3.2.jar ]; then
    pushd /opt/stage/libs >/dev/null
    wget -q https://dlm.mariadb.com/3700566/Connectors/java/connector-java-3.3.2/mariadb-java-client-3.3.2.jar
    popd >/dev/null
    echo "mariadb  /opt/stage/libs/mariadb-java-client-3.3.2.jar downloaded"
else
    echo "mariadb  /opt/stage/libs/mariadb-java-client-3.3.2.jar found"
fi

# download oracle jdbc if not there
if [ ! -f /opt/stage/libs/ojdbc8.jar ]; then
    pushd /opt/stage/libs >/dev/null
    curl -O --location https://download.oracle.com/otn-pub/otn_software/jdbc/1815/ojdbc8.jar
    popd >/dev/null
    echo "oracle /opt/stage/libs/ojdbc8.jar downloaded"
else
    echo "oracle /opt/stage/libs/ojdbc8.jar found"
fi

# download log4j
if [ ! -f /opt/stage/libs/log4j-1.2.17.jar ]; then
    pushd /opt/stage/libs >/dev/null
    curl -O --location https://repo1.maven.org/maven2/log4j/log4j/1.2.17/log4j-1.2.17.jar
    popd >/dev/null
    echo "log4j /opt/stage/libs/log4j-1.2.17.jar downloaded"
else
    echo "log4j /opt/stage/libs/log4j-1.2.17.jar found"
fi

# download sqlserver from maven
# https://learn.microsoft.com/en-us/sql/connect/jdbc/download-microsoft-jdbc-driver-for-sql-server?view=sql-server-ver16#using-the-jdbc-driver-with-maven-central
if [ ! -f /opt/stage/libs/mssql-jdbc-12.6.1.jre8.jar ]; then
    pushd /opt/stage/libs >/dev/null
    curl -O --location https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/12.6.1.jre8/mssql-jdbc-12.6.1.jre8.jar
    popd >/dev/null
    echo "sqlserver /opt/stage/libs/mssql-jdbc-12.6.1.jre8.jar downloaded"
else
    echo "sqlserver /opt/stage/libs/mssql-jdbc-12.6.1.jre8.jar found"
fi