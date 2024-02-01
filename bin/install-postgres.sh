#!/usr/bin/env bash

# install pg with wal2json plugin

[ -z "$(dpkg -l postgresql 2>/dev/null)" ] && sudo apt-get -y update && sudo apt-get -y install postgresql 

sudo apt-get -y install postgresql-$(dpkg-query --showformat='${Version}' --show postgresql | cut -d+ -f1)-wal2json postgresql-contrib dialog

# start pg with cdc and demo performance setup     
sudo pg_ctlcluster $(dpkg-query --showformat='${Version}' --show postgresql | cut -d+ -f1) main restart --options "-c wal_level=logical -c max_replication_slots=10 -c max_connections=300 -c shared_buffers=80MB -c max_wal_size=3GB"

# create arcsrc user with default database
# set synchronous_commit TO off for performance demo that recommeded for production usage
# allow replication prov
sudo -u postgres psql <<EOF
CREATE USER arcsrc PASSWORD 'Passw0rd';
create database arcsrc;
ALTER DATABASE arcsrc SET synchronous_commit TO off;
alter user arcsrc replication;
alter database arcsrc owner to arcsrc;
grant all privileges on database arcsrc to arcsrc;
EOF
# MAGIC
# create replication slot arcsrc_w2j and heartbeat that will be used by arcion
export PGPASSWORD=Passw0rd 
psql --username arcsrc --dbname arcsrc --host 127.0.0.1 <<EOF
SELECT 'init' FROM pg_create_logical_replication_slot('arcsrc_w2j', 'wal2json');
SELECT * from pg_replication_slots;
CREATE TABLE IF NOT EXISTS "REPLICATE_IO_CDC_HEARTBEAT"(
    TIMESTAMP BIGINT NOT NULL,
    PRIMARY KEY(TIMESTAMP)
);  
EOF


# create YCSB table
export PGPASSWORD=Passw0rd 
psql --username arcsrc --dbname arcsrc --host 127.0.0.1 <<EOF
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
export PGPASSWORD=Passw0rd 
psql --username arcsrc --dbname arcsrc --host 127.0.0.1 <<EOF
-- show tables
\dt
EOF