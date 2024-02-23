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

create_ycsb_table() {
  # check required param
  if [ -z "${svc_name}" ]; then "svc_name not defined"; return 1; fi
  # set default params
  if [ -z "${y_tablename}" ]; then local y_tablename="usertable"; fi
  # run
  set -x
  jsqsh -n --jdbc-class "oracle.jdbc.OracleDriver" \
  --driver oracle \
  --jdbc-url "jdbc:oracle:thin:@//ol7-19-scan:1521/${svc_name}" \
  --user "c##arcsrc" \
  --password "Passw0rd" <<EOF
  CREATE TABLE ${y_tablename} (
      YCSB_KEY NUMBER PRIMARY KEY,
      FIELD0 VARCHAR2(255), FIELD1 VARCHAR2(255),
      FIELD2 VARCHAR2(255), FIELD3 VARCHAR2(255),
      FIELD4 VARCHAR2(255), FIELD5 VARCHAR2(255),
      FIELD6 VARCHAR2(255), FIELD7 VARCHAR2(255),
      FIELD8 VARCHAR2(255), FIELD9 VARCHAR2(255)
  ) organization index; 
  select table_name from user_tables where table_name='${y_tablename^^}';
EOF
  set +x
}


# load data
pushd -n /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/
bin/ycsb.sh load jdbc -s -P workloads/workloada -p db.driver=oracle.jdbc.OracleDriver -p db.url="jdbc:oracle:thin:@//ol7-19-scan:1521/cdb_svc" -p db.user="c##arcsrc" -p db.passwd="Passw0rd" -p db.batchsize=1000  -p jdbc.fetchsize=10 -p jdbc.autocommit=true -p jdbc.batchupdateapi=true -p db.batchsize=1000 -p recordcount=100000 -p jdbc.ycsbkeyprefix=false -p insertorder=ordered 
popd

pushd -n /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/
bin/ycsb.sh load jdbc -s -P workloads/workloada -p db.driver=oracle.jdbc.OracleDriver -p db.url="jdbc:oracle:thin:@//ol7-19-scan:1521/pdb1_svc" -p db.user="c##arcsrc" -p db.passwd="Passw0rd" -p db.batchsize=1000  -p jdbc.fetchsize=10 -p jdbc.autocommit=true -p jdbc.batchupdateapi=true -p db.batchsize=1000 -p recordcount=100000 -p jdbc.ycsbkeyprefix=false -p insertorder=ordered 
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
