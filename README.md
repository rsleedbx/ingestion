# Overview

For a demo, SQL Server source is support.

## TL;DR
- Start a Personal Compute Cluster
- Open [sqlserver-arcion-dbx](sqlserver-arcion-dbx.ipynb) notebook
- Attach the notebook to the Personal Compute Cluster
- Follow the instructions in the notebook

## Purpose

This demo environment is designed to help answer the following questions:
- How does it work
- How fast is snapshot (bulk insert) performance
- How fast is realtime (CDC) performance

Demo is not for for:
- Schema and data type validation
- Tuning based on environmental factors
- Data value conversion
- HA and resilience testing 


### Infrastructures

The following is the demo environment.
```text
  +------------------ Databricks Personal Compute Cluster --------------------+  
  |  +-----------+    +-----------+          +----------+     +------------+  |
  |  |  Workload |    | Source DB |          |  Arcion  |     | Target DB  |  | 
  |  |           |    |           | <--------|   Demo   |     |            |  |
  |  |   YCSB    | -->| SQL Server|          | Notebook | --> | Databricks |  |
  |  |           |    |           | -------->|   CLI    |     |            |  |
  |  +-----------+    +-----------+          +----------+     +------------+  |
  +---------------------------------------------------------------------------+
```

In a cloud deployment, the following is the expected separation.
```text
  +----------Customer Cloud---------+   F   +---------- Databricks -----------+  
  |  +-----------+    +-----------+ |   I   | +----------+     +------------+ |
  |  |  Workload |    | Source DB | |   R   | |  Arcion  |     | Target DB  | | 
  |  |           |    |           | | <-E-- | |   Demo   |     |            | |
  |  |   YCSB    | -->| SQL Server| |   W   | | Notebook | --> | Databricks | |
  |  |           |    |           | | --A-> | |    UI    |     |            | |
  |  +-----------+    +-----------+ |   L   | +----------+     +------------+ |  
  +---------------------------------+   L   +---------------------------------+

In an on-prem deployment, the following is the expected separation.
```text
  +-------------------Customer Cloud----------------+   F   +-- Databricks --+  
  |  +-----------+    +-----------+    +----------+ |   I   | +------------+ |
  |  |  Workload |    | Source DB |    |  Arcion  | |   R   | | Target DB  | | 
  |  |           |    |           |    |   Demo   | |   E   | |            | |
  |  |   YCSB    | -->| SQL Server| -->| Notebook | |   W   | | Databricks | |
  |  |           |    |           |    |    UI    | | --A-> | |            | |
  |  +-----------+    +-----------+    +----------+ |   L   | +------------+ |  
  +-------------------------------------------------+   L   +----------------+

```

### Schema 

In the demo, there are dense and sparse tables.
Dense and sparse tables try to model a star schema.
Dense tables can be long and wide and have most of the fields populated.
Sparse tables can be short and wide if required and have most of the fields NOT populated.

- An arbitrary number of dense and sparse tables be defined.  
- Each table can have defined number of fields.  
- Range of populated fields can be defined.
- A specified number of records are inserted/appended using native bulk copy.  

Dense tables have all fields populated to data to the max length of the field.
Sparse tables fields are populated with NULLs.

```text
+--------+    +--------+  +--------+    +--------+
| Dense  |    | Dense  |  | Sparse |    | Sparse | 
| Tables | ...| Tables |  | Tables | ...| Tables |
|   1    |    |   n    |  |   1    |    |    n   |
+--------+    +--------+  +--------+    +--------+
```

Dense and sparse tables allow one to model capacity and performance of:
- Star schema
- IOT data 
- big data

### Workload

Workload uses [customized](https://github.com/arcionlabs/YCSB/tree/jdbc_url_delim) Yahoo Cloud Services Benchmark [YCSB](https://github.com/brianfrankcooper/YCSB).

### Arcion

Legacy Arcion CLI is used.

### Staging

#### DBFS

The root directory will be created if does not exist.
can be access under /dbfs/<root dir name>

