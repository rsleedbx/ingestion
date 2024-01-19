# Databricks notebook source
# DBTITLE 1,This is a demo of Arcion CDC to Databricks.  Postgres is the source DB.  YCSB data is replicated.
# MAGIC %md
# MAGIC - Install Postgres 
# MAGIC - Install wal2json plugin.
# MAGIC - Setup arcsrc schema
# MAGIC - Setup YCSB table

# COMMAND ----------

# MAGIC %sh
# MAGIC # install pg with wal2json plugin
# MAGIC [ -z "$(dpkg -l postgresql 2>/dev/null)" ] && sudo apt-get -y update && sudo apt-get -y install postgresql 
# MAGIC
# MAGIC sudo apt-get -y install postgresql-$(dpkg-query --showformat='${Version}' --show postgresql | cut -d+ -f1)-wal2json postgresql-contrib dialog

# COMMAND ----------

# MAGIC %sh
# MAGIC # start pg with cdc and demo performance setup     
# MAGIC sudo pg_ctlcluster $(dpkg-query --showformat='${Version}' --show postgresql | cut -d+ -f1) main restart --options "-c wal_level=logical -c max_replication_slots=10 -c max_connections=300 -c shared_buffers=80MB -c max_wal_size=3GB"

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
