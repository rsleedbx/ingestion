# manual setup of ingestion gateway
export ARCION_DOWNLOAD=""       # don't donwload.  use what is specified below
export ARCION_BASEDIR=/arcion   # where arcion is setup with IG
export ARCION_DIRNAME=          # no separate subdir with IG
export ARCION_HOME=/arcion
export ARCION_BIN=${ARCION_HOME}/bin/replicant

export SRCDB_ARC_USER=${SRCDB_ARC_USER:-arcsrc}
export SRCDB_ARC_PW=${SRCDB_ARC_PW:-Passw0rd}
export SRCDB_DB=${SRCDB_DB:-${SRCDB_ARC_USER}}
export SRCDB_SCHEMA=${SRCDB_SCHEMA:-dbo}
export SRCDB_USER_CHANGE=${SRCDB_USER_CHANGE:-${SRCDB_DB:-arcsrc}}

export SRCDB_ROOT_USER=sa
export SRCDB_ROOT_PW=Passw0rd

# arcion parallelism
export SRCDB_SNAPSHOT_THREADS=1
export SRCDB_DELTA_SNAPSHOT_THREADS=1
export SRCDB_REALTIME_THREADS=1

# default YCSB table name
export fq_table_name=YCSBSPARSE

