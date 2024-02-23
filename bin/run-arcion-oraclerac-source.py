#!/usr/bin/env python3

from pathlib import Path

Path("/opt/stage/demo/").mkdir(parents=True, exist_ok=True)
Path("/opt/stage/demo/oraclerac/logs").mkdir(parents=True, exist_ok=True)
Path("/opt/stage/demo/oraclerac/temp").mkdir(parents=True, exist_ok=True)

print("""
data-dir: /opt/stage/demo/oraclerac/logs
permission-validation: 
  enable: false
trace-log: #trace-log avail starting 23-05-31
  trace-level: INFO
""", file=open('/opt/stage/demo/oraclerac/general.yaml','w'))

print("""
type: ORACLE
host: 'ol7-19-scan'
port: 1521
database: 'c##arcsrc'
username: 'c##arcsrc'
password: 'Passw0rd'
max-connections: 10
max-retries: 5
""", file=open('/opt/stage/demo/oraclerac/src.yaml','w'))

print("""
type: NULLSTORAGE
storage-location: /opt/stage/demo/oraclerac/temp # schema and YAML files are written here
""", file=open('/opt/stage/demo/oraclerac/dst_null.yaml','w'))

print("""
snapshot:
  threads: 1
  _traceDBTasks: true
  fetch-user-roles: false
  _fetch-exact-row-count: false    
  fetch-size-rows: 5_000 # default=5_000 
  max-jobs-per-chunk: 80 # default=2xthreads
  min-job-size-rows: 10_000 # default=1_000_000 
""", file=open('/opt/stage/demo/oraclerac/extractor.yaml','w'))

print("""
allow:
- catalog: "arcsrc" 
  schema : "public" 
  types: [TABLE] # [TABLE,VIEW] 
  allow:  # all tables if empty
""", file=open('/opt/stage/demo/oraclerac/filter.yaml','w'))

print("""
snapshot:
  threads: 1
  skip-tables-on-failures : true
  _traceDBTasks: true
realtime:
  threads: 1
  skip-tables-on-failures : true
  txn-size-rows: 50_000 # default=5k too small for YCSB high TPS
""", file=open('/opt/stage/demo/oraclerac/applier_null.yaml','w'))


print("""
snapshot:
  threads: 1
  skip-tables-on-failures : true
  _traceDBTasks: true
realtime:
  threads: 1
  skip-tables-on-failures : true
  txn-size-rows: 50_000 # default=5k too small for YCSB high TPS
""", file=open('/opt/stage/demo/oraclerac/applier_deltalake.yaml','w'))


cd /opt/stage/demo/oraclerac
export JAVA_HOME=$( find /usr/lib/jvm/java-8-openjdk-*/jre -maxdepth 0)
/opt/stage/arcion/replicant-cli/bin/replicant snapshot src.yaml dst_null.yaml \
  --overwrite --id $$ --replace \
  --general general.yaml \
  --extractor extractor.yaml \
  --filter filter.yaml \
  --applier applier_null.yaml 

export ARCION_HOME=/opt/stage/arcion/replicate-cli-23.05.31.29
$ARCION_HOME/bin/replicate real-time src.yaml dst_null.yaml \
  --overwrite --id $$ --replace \
  --general general.yaml \
  --extractor extractor.yaml \
  --filter filter.yaml \
  --applier applier_null.yaml 

# test failover with oracle rac

-- show RAC nodes
select instance_name,host_name from gv$instance;

-- show connected node
select host_name from v$instance;


-- show the failover type and methods
select name,failover_type, failover_method from dba_services 


  -- show who connect to which node
  select i.host_name, s.username from 
    gv$session s join
    gv$instance i on (i.inst_id=s.inst_id)
  where 
    username is not null;

-- show number of connect by service name
select service_name,COUNT(*) FROM gv$session GROUP BY service_name;

-- show tables
select table_name from user_tables;