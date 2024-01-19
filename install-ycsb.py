# Databricks notebook source
# MAGIC %md
# MAGIC Install YCSB

# COMMAND ----------

# MAGIC %run ./download-jdbc

# COMMAND ----------

# MAGIC %sh
# MAGIC # download ycsb
# MAGIC if [ ! -d /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT ]; then
# MAGIC   mkdir -p /opt/stage/ycsb; cd /opt/stage/ycsb
# MAGIC   [ ! -f ycsb-jdbc-binding-0.18.0-SNAPSHOT.tar.gz ]  && curl -O --location https://github.com/arcionlabs/YCSB/releases/download/arcion-23.07/ycsb-jdbc-binding-0.18.0-SNAPSHOT.tar.gz 
# MAGIC   [ -f ycsb-jdbc-binding-0.18.0-SNAPSHOT.tar.gz ] && gzip -dc *.gz | tar -xvf -
# MAGIC fi

# COMMAND ----------

# MAGIC %sh
# MAGIC cp /opt/stage/libs/*.jar /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/lib/.
# MAGIC

# COMMAND ----------

# MAGIC %sh
# MAGIC [ ! -x tree ] && sudo apt-get update && sudo apt-get -y install tree
# MAGIC tree /opt/stage/ycsb
