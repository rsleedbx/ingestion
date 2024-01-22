#!/usr/bin/env bash

sudo mkdir -p /opt/stage/libs && chown $(logname):$(logname) /opt/stage/libs
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

# download log4j
if [ ! -f /opt/stage/libs/log4j-1.2.17.jar ]; then
    pushd /opt/stage/libs >/dev/null
    curl -O --location https://repo1.maven.org/maven2/log4j/log4j/1.2.17/log4j-1.2.17.jar
    popd >/dev/null
    echo "log4j /opt/stage/libs/log4j-1.2.17.jar downloaded"
else
    echo "log4j /opt/stage/libs/log4j-1.2.17.jar found"
fi