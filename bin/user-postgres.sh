#!/usr/bin/env bash

LOGNAME=$(logname 2>/dev/null)
LOGNAME=${LOGNAME:-root}

# create arcsrc user with default database
# set synchronous_commit TO off for performance demo that recommeded for production usage
pg_root_cli <<EOF
CREATE USER arcsrc PASSWORD 'Passw0rd';
create database arcsrc;
ALTER DATABASE arcsrc SET synchronous_commit TO off;
alter user arcsrc replication;
alter database arcsrc owner to arcsrc;
grant all privileges on database arcsrc to arcsrc;
EOF

pg_cli <<EOF
SELECT 'init' FROM pg_create_logical_replication_slot('arcsrc_w2j', 'wal2json');
SELECT * from pg_replication_slots;
CREATE TABLE IF NOT EXISTS "REPLICATE_IO_CDC_HEARTBEAT"(
    TIMESTAMP BIGINT NOT NULL,
    PRIMARY KEY(TIMESTAMP)
);  
EOF

# create default YCSB table
pg_cli <<EOF
CREATE TABLE IF NOT EXISTS usertable (
    YCSB_KEY INT PRIMARY KEY,
    FIELD0 TEXT, FIELD1 TEXT,
    FIELD2 TEXT, FIELD3 TEXT,
    FIELD4 TEXT, FIELD5 TEXT,
    FIELD6 TEXT, FIELD7 TEXT,
    FIELD8 TEXT, FIELD9 TEXT
); 
EOF

# show tables
pg_cli <<EOF
-- show tables
\dt
EOF