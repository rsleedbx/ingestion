# Databricks notebook source
# MAGIC %md
# MAGIC
# MAGIC https://www.databricks.com/spark/jdbc-drivers-download
# MAGIC
# MAGIC DatabricksJDBC42-2.6.36.1062.zip has __MACOSX that seem not necessary
# MAGIC
# MAGIC User Setting -> Developer -> Access Token -> Generate New Token
# MAGIC
# MAGIC Cluster -> Configuration -> Advanced Options -> JDBC/ODBC -> JDBC URL 2.6.25 or later
# MAGIC
# MAGIC jdbc:databricks://416411475796958.8.gcp.databricks.com:443/default;transportMode=http;ssl=1;httpPath=sql/protocolv1/o/416411475796958/0110-135057-448ddxyp;AuthMech=3;UID=token;PWD=<personal-access-token>
# MAGIC
# MAGIC For Unity Catalog
# MAGIC com.databricks.client.jdbc.Driver
# MAGIC
# MAGIC For Simba
# MAGIC val driver = "com.simba.spark.jdbc41.Driver"  //attach the Spark jar to the Classpath.
# MAGIC
# MAGIC Log msg to clean up
# MAGIC ERROR StatusLogger Unrecognized format specifier [d]
# MAGIC ERROR StatusLogger Unrecognized conversion specifier [d] starting at position 16 in conversion pattern.
# MAGIC
# MAGIC 2024-01-11T19:36:48.873+0000: [GC (Metadata GC Threshold) [PSYoungGen: 119603K->14932K(871936K)] 119603K->14956K(2865664K), 0.0281485 secs] [Times: user=0.04 sys=0.01, real=0.03 secs] 

# COMMAND ----------

# MAGIC %md
# MAGIC Install YCSB

# COMMAND ----------

# MAGIC %run ./install-ycsb

# COMMAND ----------

# MAGIC %sql
# MAGIC use robertlee.default;
# MAGIC CREATE TABLE usertable (
# MAGIC 	YCSB_KEY VARCHAR(255) PRIMARY KEY,
# MAGIC 	FIELD0 STRING, FIELD1 STRING,
# MAGIC 	FIELD2 STRING, FIELD3 STRING,
# MAGIC 	FIELD4 STRING, FIELD5 STRING,
# MAGIC 	FIELD6 STRING, FIELD7 STRING,
# MAGIC 	FIELD8 STRING, FIELD9 STRING
# MAGIC );

# COMMAND ----------

# MAGIC %sql
# MAGIC show tables

# COMMAND ----------

# MAGIC %sql
# MAGIC truncate table usertable

# COMMAND ----------

# MAGIC %sql
# MAGIC select count(*) from usertable;

# COMMAND ----------

# MAGIC %sh
# MAGIC cd /ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT
# MAGIC bin/ycsb.sh load jdbc -s -P workloads/workloada -p db.driver=com.databricks.client.jdbc.Driver -p db.url="jdbc:databricks://416411475796958.8.gcp.databricks.com:443/default;ConnCatalog=robertlee;transportMode=http;ssl=1;httpPath=sql/protocolv1/o/416411475796958/0110-135057-448ddxyp;AuthMech=3;" -p db.user=token -p db.passwd="$PASSWORD" -p db.batchsize=1000  -p jdbc.fetchsize=10 -p jdbc.autocommit=true -p jdbc.batchupdateapi=true -p recordcount=100000 -p db.urlsharddelim='___'
# MAGIC

# COMMAND ----------

# MAGIC %sh
# MAGIC cd /ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT
# MAGIC bin/ycsb.sh run jdbc -s -P workloads/workloada -p db.driver=com.databricks.client.jdbc.Driver -p db.url="jdbc:databricks://416411475796958.8.gcp.databricks.com:443/default;ConnCatalog=robertlee;transportMode=http;ssl=1;httpPath=sql/protocolv1/o/416411475796958/0110-135057-448ddxyp;AuthMech=3;" -p db.user=token -p db.passwd="$PASSWORD" -p db.batchsize=1000  -p jdbc.fetchsize=10 -p jdbc.autocommit=true -p jdbc.batchupdateapi=true -p recordcount=1000 -p db.urlsharddelim='___'

# COMMAND ----------


