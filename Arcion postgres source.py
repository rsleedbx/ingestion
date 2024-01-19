# Databricks notebook source
# DBTITLE 1,This is a demo of Arcion CDC to Databricks.  Postgres is the source DB.  YCSB data is replicated.
# MAGIC %md
# MAGIC - Install Postgres with wal2json plugin.
# MAGIC - Install YCSB.
# MAGIC - Install Arcion.
# MAGIC - Install Postgres and Databricks JDBC drivers.

# COMMAND ----------

dbutils.widgets.text("Arcion License","")

# COMMAND ----------

# MAGIC %sh
# MAGIC # install pg with wal2json plugin
# MAGIC sudo apt-get -y update && sudo apt-get -y install postgresql postgresql-12-wal2json postgresql-contrib dialog

# COMMAND ----------

# MAGIC %sh
# MAGIC # start pg with cdc and demo performance setup     
# MAGIC pg_ctlcluster 12 main start --options "-c wal_level=logical -c max_replication_slots=10 -c max_connections=300 -c shared_buffers=80MB -c max_wal_size=3GB"

# COMMAND ----------

# MAGIC %sh
# MAGIC # create arcsrc user with default database
# MAGIC # set synchronous_commit TO off for performance demo that recommeded for production usage
# MAGIC # allow replication prov
# MAGIC sudo -u postgres psql <<EOF
# MAGIC CREATE USER arcsrc PASSWORD 'Passw0rd';
# MAGIC create database arcsrc;
# MAGIC ALTER DATABASE arcsrc SET synchronous_commit TO off;
# MAGIC alter user arcsrc replication;
# MAGIC alter database arcsrc owner to arcsrc;
# MAGIC grant all privileges on database arcsrc to arcsrc;
# MAGIC EOF
# MAGIC
# MAGIC # create replication slot arcsrc_w2j and heartbeat that will be used by arcion
# MAGIC export PGPASSWORD=Passw0rd 
# MAGIC psql --username arcsrc --dbname arcsrc --host 127.0.0.1 <<EOF
# MAGIC SELECT 'init' FROM pg_create_logical_replication_slot('arcsrc_w2j', 'wal2json');
# MAGIC SELECT * from pg_replication_slots;
# MAGIC CREATE TABLE IF NOT EXISTS "REPLICATE_IO_CDC_HEARTBEAT"(
# MAGIC     TIMESTAMP BIGINT NOT NULL,
# MAGIC     PRIMARY KEY(TIMESTAMP)
# MAGIC );  
# MAGIC EOF
# MAGIC

# COMMAND ----------

# MAGIC %sh
# MAGIC # create YCSB table
# MAGIC export PGPASSWORD=Passw0rd 
# MAGIC psql --username arcsrc --dbname arcsrc --host 127.0.0.1 <<EOF
# MAGIC CREATE TABLE IF NOT EXISTS usertable (
# MAGIC     YCSB_KEY INT PRIMARY KEY,
# MAGIC     FIELD0 TEXT, FIELD1 TEXT,
# MAGIC     FIELD2 TEXT, FIELD3 TEXT,
# MAGIC     FIELD4 TEXT, FIELD5 TEXT,
# MAGIC     FIELD6 TEXT, FIELD7 TEXT,
# MAGIC     FIELD8 TEXT, FIELD9 TEXT
# MAGIC ); 
# MAGIC EOF

# COMMAND ----------

# MAGIC %sh
# MAGIC # add postgres jdbc to ycsb
# MAGIC if [ -d /ycsb ]; then
# MAGIC   cd /ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/lib && curl -s -O https://jdbc.postgresql.org/download/postgresql-42.7.1.jar
# MAGIC fi  

# COMMAND ----------

# MAGIC %sh
# MAGIC # load data
# MAGIC cd /ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT
# MAGIC bin/ycsb.sh load jdbc -s -P workloads/workloada -p db.driver=org.postgresql.Driver -p db.url="jdbc:postgresql://127.0.0.1/?autoReconnect=true&sslmode=disable&ssl=false&reWriteBatchedInserts=true" -p db.user=arcsrc -p db.passwd="Passw0rd" -p db.batchsize=1000  -p jdbc.fetchsize=10 -p jdbc.autocommit=true -p jdbc.batchupdateapi=true -p db.batchsize=1000 -p recordcount=100000 -p jdbc.ycsbkeyprefix=false -p insertorder=ordered 

# COMMAND ----------

# MAGIC %sh
# MAGIC # count the rows in the usertable (YCSB)
# MAGIC export PGPASSWORD=Passw0rd 
# MAGIC psql --username arcsrc --dbname arcsrc --host 127.0.0.1 <<EOF
# MAGIC SELECT count(*) from usertable;
# MAGIC EOF

# COMMAND ----------

# MAGIC %sh
# MAGIC # update at TPS=as fast as possible
# MAGIC cd /ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT
# MAGIC bin/ycsb.sh run jdbc -s -P workloads/workloada -p db.driver=org.postgresql.Driver -p db.url="jdbc:postgresql://127.0.0.1/?autoReconnect=true&sslmode=disable&ssl=false" -p db.user=arcsrc -p db.passwd="Passw0rd" -p db.batchsize=1000  -p jdbc.fetchsize=10 -p jdbc.autocommit=true -p jdbc.batchupdateapi=true -p db.batchsize=1000 -p recordcount=100000 -p jdbc.ycsbkeyprefix=false -p insertorder=ordered -p operationcount=100000 -p readproportion=0 -p updateproportion=1 -threads 1 -target 0 >/var/tmp/ycsb.run.tps0.$$ 2>&1 &
# MAGIC YCSB_PID=$!
# MAGIC echo "YCSB_PID=$YCSB_PID"
# MAGIC echo "Check the log at /var/tmp/ycsb.run.tps0.$$"

# COMMAND ----------

# MAGIC %sh
# MAGIC # update at TPS=1 in the background
# MAGIC cd /ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT
# MAGIC bin/ycsb.sh run jdbc -s -P workloads/workloada -p db.driver=org.postgresql.Driver -p db.url="jdbc:postgresql://127.0.0.1/?autoReconnect=true&sslmode=disable&ssl=false" -p db.user=arcsrc -p db.passwd="Passw0rd" -p db.batchsize=1000  -p jdbc.fetchsize=10 -p jdbc.autocommit=true -p jdbc.batchupdateapi=true -p db.batchsize=1000 -p recordcount=100000 -p jdbc.ycsbkeyprefix=false -p insertorder=ordered -p operationcount=100000 -p readproportion=0 -p updateproportion=1 -threads 1 -target 1 >/var/tmp/ycsb.run.tps1.$$ 2>&1 &
# MAGIC YCSB_PID=$!
# MAGIC echo "YCSB_PID=$YCSB_PID"
# MAGIC echo "Check the log at /var/tmp/ycsb.run.tps1.$$"

# COMMAND ----------



# COMMAND ----------



# COMMAND ----------

cat >src.yaml <<EOF
type: POSTGRESQL
host: '127.0.0.1'
port: 5432
database: 'arcsrc'
username: 'arcsrc'
password: 'Passw0rd'
max-connections: 10
replication-slots:
  arcsrc_w2j: 
    - wal2json
log-reader-type: STREAM # {STREAM|SQL deprecated}
max-retries: 5
EOF



# COMMAND ----------

cat >dst.yaml <<EOF
type: DATABRICKS_DELTALAKE
url: '${DBX_DL_URL_AZURE}'
port: 443 
username: 'token'
password: '${DBX_DL_PW_AZURE}'
max-connections: 5 
max-retries: 1
stage:
  root-dir: replicate-stage/databricks-stage
  type: DATABRICKS_DBFS
EOF
