# Databricks notebook source
# MAGIC %sh
# MAGIC sudo mkdir -p /opt/stage/libs && chown $(logname):$(logname) /opt/stage/libs
# MAGIC # deltalake
# MAGIC if [ ! -f /opt/stage/libs/SparkJDBC42.jar ]; then
# MAGIC     pushd /opt/stage/libs >/dev/null
# MAGIC     wget -q https://databricks-bi-artifacts.s3.us-east-2.amazonaws.com/simbaspark-drivers/jdbc/2.6.22/SimbaSparkJDBC42-2.6.22.1040.zip
# MAGIC     unzip -q SimbaSparkJDBC42-2.6.22.1040.zip
# MAGIC     rm SimbaSparkJDBC42-2.6.22.1040.zip
# MAGIC     rm -rf docs EULA.txt 2>/dev/null
# MAGIC     popd >/dev/null
# MAGIC     echo "deltalake /opt/stage/libs/SparkJDBC42.jar downloaded"
# MAGIC else
# MAGIC     echo "deltalake /opt/stage/libs/SparkJDBC42.jar found"
# MAGIC fi
# MAGIC
# MAGIC # lakehouse (unity catalog)
# MAGIC if [ ! -f /opt/stage/libs/DatabricksJDBC42.jar ]; then
# MAGIC     pushd /opt/stage/libs >/dev/null
# MAGIC     wget -q https://repo1.maven.org/maven2/com/databricks/databricks-jdbc/2.6.34/databricks-jdbc-2.6.34.jar
# MAGIC     mv databricks-jdbc-2.6.34.jar DatabricksJDBC42.jar
# MAGIC     rm -rf docs EULA.txt 2>/dev/null
# MAGIC     popd >/dev/null
# MAGIC     echo "lakehouse  /opt/stage/libs/DatabricksJDBC42.jar downloaded"
# MAGIC else
# MAGIC     echo "lakehouse  /opt/stage/libs/DatabricksJDBC42.jar found"
# MAGIC fi
# MAGIC
# MAGIC # postgres
# MAGIC if [ ! -f /opt/stage/libs/postgresql-42.7.1.jar ]; then
# MAGIC     pushd /opt/stage/libs >/dev/null
# MAGIC     wget -q https://jdbc.postgresql.org/download/postgresql-42.7.1.jar
# MAGIC     popd >/dev/null
# MAGIC     echo "postgres  /opt/stage/libs/postgresql-42.7.1.jar downloaded"
# MAGIC else
# MAGIC     echo "postgres  /opt/stage/libs/postgresql-42.7.1.jar found"
# MAGIC fi
# MAGIC
# MAGIC # download log4j
# MAGIC if [ ! -f /opt/stage/libs/log4j-1.2.17.jar ]; then
# MAGIC     pushd /opt/stage/libs >/dev/null
# MAGIC     curl -O --location https://repo1.maven.org/maven2/log4j/log4j/1.2.17/log4j-1.2.17.jar
# MAGIC     popd >/dev/null
# MAGIC     echo "log4j /opt/stage/libs/log4j-1.2.17.jar downloaded"
# MAGIC else
# MAGIC     echo "log4j /opt/stage/libs/log4j-1.2.17.jar found"
# MAGIC fi
