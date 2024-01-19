# Databricks notebook source
# DBTITLE 1,This is a demo of Arcion CDC to Databricks.  Postgres is the source DB.  YCSB data is replicated.
# MAGIC %md
# MAGIC - Install Postgres with wal2json plugin.
# MAGIC - Install YCSB.
# MAGIC - Install Arcion.
# MAGIC - Install Postgres and Databricks JDBC drivers.

# COMMAND ----------

# MAGIC %run ./install-postgres

# COMMAND ----------

# MAGIC %run ./install-ycsb

# COMMAND ----------

# MAGIC %run ./install-arcion

# COMMAND ----------

# MAGIC %run ./run-ycsb-postgres-source

# COMMAND ----------

# MAGIC %sh
# MAGIC mkdir -p /opt/stage/demo/pg
# MAGIC mkdir -p /opt/stage/demo/pg/logs
# MAGIC mkdir -p /opt/stage/demo/pg/temp
# MAGIC
# MAGIC cd /opt/stage/demo/pg
# MAGIC
# MAGIC cat >general.yaml <<EOF
# MAGIC data-dir: /opt/stage/demo/pg/logs
# MAGIC permission-validation: 
# MAGIC   enable: false
# MAGIC trace-log: #trace-log avail starting 23-05-31
# MAGIC   trace-level: INFO
# MAGIC EOF
# MAGIC
# MAGIC cat >src.yaml <<EOF
# MAGIC type: POSTGRESQL
# MAGIC host: '127.0.0.1'
# MAGIC port: 5432
# MAGIC database: 'arcsrc'
# MAGIC username: 'arcsrc'
# MAGIC password: 'Passw0rd'
# MAGIC max-connections: 10
# MAGIC replication-slots:
# MAGIC   arcsrc_w2j: 
# MAGIC     - wal2json
# MAGIC log-reader-type: STREAM # {STREAM|SQL deprecated}
# MAGIC max-retries: 5
# MAGIC EOF
# MAGIC
# MAGIC cat >dst_null.yaml <<EOF
# MAGIC type: NULLSTORAGE
# MAGIC storage-location: /opt/stage/demo/pg/temp # schema and YAML files are written here
# MAGIC EOF
# MAGIC
# MAGIC cat >extractor.yaml <<EOF
# MAGIC snapshot:
# MAGIC   threads: 1
# MAGIC   _traceDBTasks: true
# MAGIC   fetch-user-roles: false
# MAGIC   _fetch-exact-row-count: false    
# MAGIC   fetch-size-rows: 5_000 # default=5_000 
# MAGIC   max-jobs-per-chunk: 80 # default=2xthreads
# MAGIC   min-job-size-rows: 10_000 # default=1_000_000 
# MAGIC EOF
# MAGIC
# MAGIC cat >filter.yaml <<EOF
# MAGIC allow:
# MAGIC - catalog: "arcsrc" 
# MAGIC   schema : "public" 
# MAGIC   types: [TABLE] # [TABLE,VIEW] 
# MAGIC   allow:  # all tables if empty
# MAGIC EOF
# MAGIC
# MAGIC cat >applier_null.yaml <<EOF
# MAGIC snapshot:
# MAGIC   threads: 1
# MAGIC   skip-tables-on-failures : true
# MAGIC   _traceDBTasks: true
# MAGIC realtime:
# MAGIC   threads: 1
# MAGIC   skip-tables-on-failures : true
# MAGIC   txn-size-rows: 50_000 # default=5k too small for YCSB high TPS
# MAGIC EOF
# MAGIC
# MAGIC cat >applier_deltalake.yaml <<EOF
# MAGIC snapshot:
# MAGIC   threads: 1
# MAGIC   skip-tables-on-failures : true
# MAGIC   _traceDBTasks: true
# MAGIC realtime:
# MAGIC   threads: 1
# MAGIC   skip-tables-on-failures : true
# MAGIC   txn-size-rows: 50_000 # default=5k too small for YCSB high TPS
# MAGIC EOF

# COMMAND ----------

# MAGIC %sh
# MAGIC cd /opt/stage/demo/pg
# MAGIC /opt/stage/arcion/replicant-cli/bin/replicant snapshot src.yaml dst_null.yaml \
# MAGIC   --overwrite --id $$ --replace \
# MAGIC   --general general.yaml \
# MAGIC   --extractor extractor.yaml \
# MAGIC   --filter filter.yaml \
# MAGIC   --applier applier_null.yaml 

# COMMAND ----------

# MAGIC %sh
# MAGIC cd /opt/stage/demo/pg
# MAGIC /opt/stage/arcion/replicant-cli/bin/replicant full src.yaml dst_null.yaml \
# MAGIC   --overwrite --id $$ --replace \
# MAGIC   --general general.yaml \
# MAGIC   --extractor extractor.yaml \
# MAGIC   --filter filter.yaml \
# MAGIC   --applier applier_null.yaml 

# COMMAND ----------

print (f"""
type: DATABRICKS_DELTALAKE
url: 'jdbc:spark://{dbutils.widgets.get('HOSTNAME')}:443/default;transportMode=http;ssl=1;httpPath={dbutils.widgets.get('HTTP_PATH')};AuthMech=3;UID=token'
host: {dbutils.widgets.get('HOSTNAME')}
port: 443 
username: 'token'
password: '{dbutils.widgets.get('ACCESS_TOKEN')}'
max-connections: 5 
max-retries: 1
stage:
  type: DATABRICKS_DBFS
  root-dir: /robert_lee/databricks-stage
  use-credentials: false
  token: ''
""", file=open('/opt/stage/demo/pg/dst_deltalake.yaml','w'))

# COMMAND ----------

# MAGIC %sh
# MAGIC cd /opt/stage/demo/pg
# MAGIC /opt/stage/arcion/replicant-cli/bin/replicant full src.yaml dst_deltalake.yaml \
# MAGIC   --overwrite --id $$ --replace \
# MAGIC   --general general.yaml \
# MAGIC   --extractor extractor.yaml \
# MAGIC   --filter filter.yaml \
# MAGIC   --applier applier_deltalake.yaml 
