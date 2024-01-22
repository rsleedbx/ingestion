#!/usr/bin/env python3

from pathlib import Path

Path("/opt/stage/demo/pg").mkdir(parents=True, exist_ok=True)
Path("/opt/stage/demo/pg/logs").mkdir(parents=True, exist_ok=True)
Path("/opt/stage/demo/pg/temp").mkdir(parents=True, exist_ok=True)

print("""
data-dir: /opt/stage/demo/pg/logs
permission-validation: 
  enable: false
trace-log: #trace-log avail starting 23-05-31
  trace-level: INFO
""", file=open('/opt/stage/demo/pg/general.yaml','w'))

print("""
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
""", file=open('/opt/stage/demo/pg/src.yaml','w'))

print("""
type: NULLSTORAGE
storage-location: /opt/stage/demo/pg/temp # schema and YAML files are written here
""", file=open('/opt/stage/demo/pg/dst_null.yaml','w'))

print("""
snapshot:
  threads: 1
  _traceDBTasks: true
  fetch-user-roles: false
  _fetch-exact-row-count: false    
  fetch-size-rows: 5_000 # default=5_000 
  max-jobs-per-chunk: 80 # default=2xthreads
  min-job-size-rows: 10_000 # default=1_000_000 
""", file=open('/opt/stage/demo/pg/extractor.yaml','w'))

print("""
allow:
- catalog: "arcsrc" 
  schema : "public" 
  types: [TABLE] # [TABLE,VIEW] 
  allow:  # all tables if empty
""", file=open('/opt/stage/demo/pg/filter.yaml','w'))

print("""
snapshot:
  threads: 1
  skip-tables-on-failures : true
  _traceDBTasks: true
realtime:
  threads: 1
  skip-tables-on-failures : true
  txn-size-rows: 50_000 # default=5k too small for YCSB high TPS
""", file=open('/opt/stage/demo/pg/applier_null.yaml','w'))


print("""
snapshot:
  threads: 1
  skip-tables-on-failures : true
  _traceDBTasks: true
realtime:
  threads: 1
  skip-tables-on-failures : true
  txn-size-rows: 50_000 # default=5k too small for YCSB high TPS
""", file=open('/opt/stage/demo/pg/applier_deltalake.yaml','w'))
