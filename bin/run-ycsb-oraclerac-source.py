# Databricks notebook source
# DBTITLE 1,This is a demo of Arcion CDC to Databricks.  Postgres is the source DB.  YCSB data is replicated.
%md
- Install Postgres with wal2json plugin.
- Install YCSB.
- Install Arcion.
- Install Postgres and Databricks JDBC drivers.

# COMMAND ----------

%run ./install-ycsb

# COMMAND ----------

%run ./install-postgres

# COMMAND ----------

%sh
# load data
pushd /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/
bin/ycsb.sh load jdbc -s -P workloads/workloada -p db.driver=oracle.jdbc.OracleDriver -p db.url="jdbc:oracle:thin:@//ol7-19-scan:1521/cdbrac" -p db.user="c##arcsrc" -p db.passwd="Passw0rd" -p db.batchsize=1000  -p jdbc.fetchsize=10 -p jdbc.autocommit=true -p jdbc.batchupdateapi=true -p db.batchsize=1000 -p recordcount=100000 -p jdbc.ycsbkeyprefix=false -p insertorder=ordered 
popd

# COMMAND ----------

%sh
# count the rows in the usertable (YCSB)
jsqsh -n -v headers=false -v footers=false arcsrc <<EOF
SELECT count(*) from usertable; -m csv
EOF

# COMMAND ----------

%sh
# update at TPS=as fast as possible
pushd /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/
bin/ycsb.sh run jdbc -s -P workloads/workloada -p db.driver=oracle.jdbc.OracleDriver -p db.url="jdbc:oracle:thin:@//ol7-19-scan:1521/cdbrac" -p db.user="c##arcsrc" -p db.passwd="Passw0rd" -p db.batchsize=1000  -p jdbc.fetchsize=10 -p jdbc.autocommit=true -p jdbc.batchupdateapi=true -p db.batchsize=1000 -p recordcount=100000 -p jdbc.ycsbkeyprefix=false -p insertorder=ordered -p operationcount=100000 -p readproportion=0 -p updateproportion=1 -threads 1 -target 0 >/var/tmp/ycsb.run.tps0.$$ 2>&1 &
YCSB_PID=$!
echo "YCSB_PID=$YCSB_PID"
echo "Check the log at /var/tmp/ycsb.run.tps0.$$"
popd

# COMMAND ----------

%sh
# update at TPS=1 in the background
pushd /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/
bin/ycsb.sh run jdbc -s -P workloads/workloada -p db.driver=oracle.jdbc.OracleDriver -p db.url="jdbc:oracle:thin:@//ol7-19-scan:1521/cdb_svc" -p db.user="c##arcsrc" -p db.passwd="Passw0rd" -p db.batchsize=1000  -p jdbc.fetchsize=10 -p jdbc.autocommit=true -p jdbc.batchupdateapi=true -p db.batchsize=1000 -p recordcount=100000 -p jdbc.ycsbkeyprefix=false -p insertorder=ordered -p operationcount=100000 -p readproportion=0 -p updateproportion=1 -threads 1 -target 1 >/var/tmp/ycsb.run.tps1.$$ 2>&1 &
YCSB_PID=$!
echo "YCSB_PID=$YCSB_PID"
echo "Check the log at /var/tmp/ycsb.run.tps1.$$"
popd
