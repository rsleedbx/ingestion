# Databricks notebook source
# DBTITLE 1,This is a demo of Arcion CDC to Databricks.  Postgres is the source DB.  YCSB data is replicated.
# MAGIC %md
# MAGIC - Install Postgres with wal2json plugin.
# MAGIC - Install YCSB.
# MAGIC - Install Arcion.
# MAGIC - Install Postgres and Databricks JDBC drivers.

# COMMAND ----------

# MAGIC %run ./install-ycsb

# COMMAND ----------

# MAGIC %run ./install-postgres

# COMMAND ----------

# MAGIC %sh
# MAGIC # load data
# MAGIC pushd /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/
# MAGIC bin/ycsb.sh load jdbc -s -P workloads/workloada -p db.driver=org.postgresql.Driver -p db.url="jdbc:postgresql://127.0.0.1/?autoReconnect=true&sslmode=disable&ssl=false&reWriteBatchedInserts=true" -p db.user=arcsrc -p db.passwd="Passw0rd" -p db.batchsize=1000  -p jdbc.fetchsize=10 -p jdbc.autocommit=true -p jdbc.batchupdateapi=true -p db.batchsize=1000 -p recordcount=100000 -p jdbc.ycsbkeyprefix=false -p insertorder=ordered 
# MAGIC popd

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
# MAGIC pushd /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/
# MAGIC bin/ycsb.sh run jdbc -s -P workloads/workloada -p db.driver=org.postgresql.Driver -p db.url="jdbc:postgresql://127.0.0.1/?autoReconnect=true&sslmode=disable&ssl=false" -p db.user=arcsrc -p db.passwd="Passw0rd" -p db.batchsize=1000  -p jdbc.fetchsize=10 -p jdbc.autocommit=true -p jdbc.batchupdateapi=true -p db.batchsize=1000 -p recordcount=100000 -p jdbc.ycsbkeyprefix=false -p insertorder=ordered -p operationcount=100000 -p readproportion=0 -p updateproportion=1 -threads 1 -target 0 >/var/tmp/ycsb.run.tps0.$$ 2>&1 &
# MAGIC YCSB_PID=$!
# MAGIC echo "YCSB_PID=$YCSB_PID"
# MAGIC echo "Check the log at /var/tmp/ycsb.run.tps0.$$"
# MAGIC popd

# COMMAND ----------

# MAGIC %sh
# MAGIC # update at TPS=1 in the background
# MAGIC pushd /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/
# MAGIC bin/ycsb.sh run jdbc -s -P workloads/workloada -p db.driver=org.postgresql.Driver -p db.url="jdbc:postgresql://127.0.0.1/?autoReconnect=true&sslmode=disable&ssl=false" -p db.user=arcsrc -p db.passwd="Passw0rd" -p db.batchsize=1000  -p jdbc.fetchsize=10 -p jdbc.autocommit=true -p jdbc.batchupdateapi=true -p db.batchsize=1000 -p recordcount=100000 -p jdbc.ycsbkeyprefix=false -p insertorder=ordered -p operationcount=100000 -p readproportion=0 -p updateproportion=1 -threads 1 -target 1 >/var/tmp/ycsb.run.tps1.$$ 2>&1 &
# MAGIC YCSB_PID=$!
# MAGIC echo "YCSB_PID=$YCSB_PID"
# MAGIC echo "Check the log at /var/tmp/ycsb.run.tps1.$$"
# MAGIC popd
