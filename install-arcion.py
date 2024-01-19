# Databricks notebook source
# MAGIC %md
# MAGIC # Install Arcion
# MAGIC - Recommend unrestriced, single node
# MAGIC - 4 cores, 16GB of RAM sufficent for testing and demo

# COMMAND ----------

# MAGIC %run ./download-jars

# COMMAND ----------

# MAGIC %sh
# MAGIC [ -z "$(dpkg -l unzip)" ] && sudo apt-get -y update && apt-get -u install unzip

# COMMAND ----------

# MAGIC %sh
# MAGIC # download and unzip arcion
# MAGIC if [ ! -f /opt/stage/arcion/replicant-cli/bin/replicant ]; then
# MAGIC   mkdir -p /opt/stage/arcion
# MAGIC   cd /opt/stage/arcion && curl -O --location https://arcion-releases.s3.us-west-1.amazonaws.com/general/replicant/replicant-cli-23.09.29.11.zip
# MAGIC   unzip -q replicant-cli-*.zip
# MAGIC   rm replicant-cli-*.zip
# MAGIC fi
# MAGIC /opt/stage/arcion/replicant-cli/bin/replicant version
# MAGIC
# MAGIC

# COMMAND ----------

# MAGIC %sh 
# MAGIC [ ! -f /opt/stage/arcion/replicant-cli/lib/SparkJDBC42.jar ] && cp /opt/stage/libs/SparkJDBC42.jar /opt/stage/arcion/replicant-cli/lib/. 
# MAGIC ls /opt/stage/arcion/replicant-cli/lib/SparkJDBC42.jar
# MAGIC
# MAGIC [ ! -f /opt/stage/arcion/replicant-cli/lib/DatabricksJDBC42.jar ] && cp /opt/stage/libs/DatabricksJDBC42.jar /opt/stage/arcion/replicant-cli/lib/.
# MAGIC ls /opt/stage/arcion/replicant-cli/lib/DatabricksJDBC42.jar
# MAGIC
# MAGIC [ ! -f /opt/stage/arcion/replicant-cli/lib/log4j-1.2.17.jar ] && cp /opt/stage/libs/log4j-1.2.17.jar /opt/stage/arcion/replicant-cli/lib/.
# MAGIC ls /opt/stage/arcion/replicant-cli/lib/log4j-1.2.17.jar
# MAGIC

# COMMAND ----------

import subprocess;
subprocess.run(f"echo '{dbutils.widgets.get('ARCION_LICENSE')}' | base64 --decode > /opt/stage/arcion/replicant-cli/replicant.lic",shell=True)

# COMMAND ----------

# MAGIC %sh
# MAGIC /opt/stage/arcion/replicant-cli/bin/replicant version
