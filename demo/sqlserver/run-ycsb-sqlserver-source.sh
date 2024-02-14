#!/usr/env/bin/bash

if [ -z "${BASH_SOURCE}" ]; then 
  echo "Please invoke using bash" 
  exit 1
fi

PROG_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
INITDB_LOG_DIR=${PROG_DIR}/config
(return 0 2>/dev/null) && export SCRIPT_SOURCED=1 || export SCRIPT_SOURCED=0

create_user() {
  sql_root_cli <<EOF
  CREATE LOGIN ${SRCDB_ARC_USER} WITH PASSWORD = '${SRCDB_ARC_PW}'
  go
  create database ${SRCDB_DB}
  go
  use ${SRCDB_DB}
  go
  CREATE USER ${SRCDB_ARC_USER} FOR LOGIN ${SRCDB_ARC_USER} WITH DEFAULT_SCHEMA=dbo
  go
  ALTER ROLE db_owner ADD MEMBER ${SRCDB_ARC_USER}
  go
  ALTER ROLE db_ddladmin ADD MEMBER ${SRCDB_ARC_USER}
  go
  alter user ${SRCDB_ARC_USER} with default_schema=dbo
  go
  ALTER LOGIN ${SRCDB_ARC_USER} WITH DEFAULT_DATABASE=[${SRCDB_DB}]
  go
  -- required for change tracking
  -- ALTER DATABASE ${SRCDB_DB} SET CHANGE_TRACKING = ON  
  -- (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON) -- required for CDC
  -- go
  -- required for CDC
  -- EXEC sys.sp_cdc_enable_db 
  -- go
EOF

}

#
kill_recurse() {
    if [ -z "${1}" ]; then return 0; fi

    cpids=$(pgrep -P $1 | xargs)
    for cpid in $cpids;
    do
        kill_recurse $cpid
    done
    kill -9 $1 2>/dev/null
}

# heredoc_file filename 
heredoc_file() {
    eval "$( echo -e '#!/usr/bin/env bash\ncat << EOF_EOF_EOF' | cat - $1 <(echo -e '\nEOF_EOF_EOF') )"    
}

# 1=""
sf_to_name() {
    if [[ "${1}" = "1" ]]; then echo ""; else echo ${1}; fi
}

# https://learn.microsoft.com/en-us/sql/tools/bcp-utility?view=sql-server-ver16
# bcp does not support pipe. materialize the file, then load

load_dense_data() {
    local SIZE_FACTOR=${1:-${SIZE_FACTOR:-1}}
    local SIZE_FACTOR_NAME=$(sf_to_name $SIZE_FACTOR)
    echo "Starting dense table $SIZE_FACTOR" 

    # create table
    heredoc_file ${PROG_DIR}/lib/03_densetable.sql > ${INITDB_LOG_DIR}/03_densetable.sql 
    sql_cli < ${INITDB_LOG_DIR}/03_densetable.sql 
    echo "${INITDB_LOG_DIR}/03_densetable.sql" 

    # prepare bulk loader
    heredoc_file ${PROG_DIR}/lib/03_densetable.fmt > ${INITDB_LOG_DIR}/03_densetable.fmt
    echo "${INITDB_LOG_DIR}/03_densetable.fmt" 

    # prepare data file
    datafile=$(mktemp -p $INITDB_LOG_DIR)
    make_ycsb_dense_data $datafile ${SIZE_FACTOR}
    
    # run the bulk loader
    # batch of 1M
    # -u trust certifcate
    time bcp YCSBDENSE${SIZE_FACTOR_NAME} in "$datafile" -S "$SRCDB_HOST,$SRCDB_PORT" -U "${SRCDB_ARC_USER}" -P "${SRCDB_ARC_PW}" -u -d arcsrc -f ${INITDB_LOG_DIR}/03_densetable.fmt -b 10000 | tee ${INITDB_LOG_DIR}/03_densetable.log

    # delete datafile
    rm $datafile

    echo "Finished dense table $SIZE_FACTOR" 
}

load_sparse_data() {
    local SIZE_FACTOR=${1:-${SIZE_FACTOR:-1}}
    local SIZE_FACTOR_NAME=$(sf_to_name $SIZE_FACTOR)
    echo "Starting sparse table $SIZE_FACTOR" 

    # create table
    heredoc_file ${PROG_DIR}/lib/03_sparsetable.sql > ${INITDB_LOG_DIR}/03_sparsetable.sql 
    sql_cli < ${INITDB_LOG_DIR}/03_sparsetable.sql 
    echo "${INITDB_LOG_DIR}/03_sparsetable.sql"

    # prepare bulk loader
    heredoc_file ${PROG_DIR}/lib/03_sparsetable.fmt > ${INITDB_LOG_DIR}/03_sparsetable.fmt
    echo "${INITDB_LOG_DIR}/03_sparsetable.fmt"

    # prepare data file
    datafile=$(mktemp -p $INITDB_LOG_DIR)
    make_ycsb_sparse_data $datafile ${SIZE_FACTOR}
    
    # run the bulk loader
    # batch of 1M
    # tablename=YCSBSPARSE${SIZE_FACTOR_NAME}
    # -u trust certifcate
    time bcp YCSBSPARSE${SIZE_FACTOR_NAME} in "$datafile" -S "$SRCDB_HOST,$SRCDB_PORT" -U "${SRCDB_ARC_USER}" -P "${SRCDB_ARC_PW}" -u -d arcsrc -f ${INITDB_LOG_DIR}/03_sparsetable.fmt -b 1000000 | tee ${INITDB_LOG_DIR}/03_sparsetable.log

    # delete datafile
    rm $datafile   

    echo "Finished sparse table $SIZE_FACTOR" 
}

make_ycsb_sparse_data() {
    local datafile=${1:-$(mktemp -p $INITDB_LOG_DIR)}
    local SIZE_FACTOR=${2:-${SIZE_FACTOR:-1}}

    rm -rf $datafile >/dev/null 2>&1
    #mkfifo ${datafile}
    local y_recordcount=${y_recordcount_sparse:-1000000}
    seq 0 $(( ${y_recordcount} * ${SIZE_FACTOR:-1} - 1 )) > ${datafile}
}

make_ycsb_dense_data() {
    local datafile=${1:-$(mktemp -p $INITDB_LOG_DIR)}
    local SIZE_FACTOR=${2:-${SIZE_FACTOR:-1}}


    rm -rf $datafile >/dev/null 2>&1
    #mkfifo ${datafile}
    # hardcoded data dense generator
    # seq 0 $(( 10000*${SIZE_FACTOR:-1} - 1 )) | \
    #    awk '{printf "%10d,%0100d,%0100d,%0100d,%0100d,%0100d,%0100d,%0100d,%0100d,%0100d,%0100d\n", \
    #        $1,$1,$1,$1,$1,$1,$1,$1,$1,$1,$1}' > ${datafile}

    local y_fieldcount=${y_fieldcount_dense:-10}
    local y_fieldlength=${y_fieldlength_dense:-100}
    local y_recordcount=${y_recordcount_dense:-10000}
    seq 0 $(( ${y_recordcount} * ${SIZE_FACTOR:-1} - 1 )) | \
        awk "{printf \"%10d\",\$1; for (i=1;i<=${y_fieldcount};i++) printf \",%0${y_fieldlength}d\",\$1; printf \"\n\"}" > ${datafile}
}

sql_cli() {
  # when stdin is redirected
  # -I enable quite identified
  # -h-1 remove header and -----
  # -W remove trailing spaces
  # -s ","
  # -w width of the screen
  if [ ! -t 0 ]; then
    local sql_cli_batch_mode="-h-1 -W -s , -w 1024"
    cat <(echo "set NOCOUNT ON") - | \
    sqlcmd -I -d "$SRCDB_DB" -S "$SRCDB_HOST,$SRCDB_PORT" -U "${SRCDB_ARC_USER}" -P "${SRCDB_ARC_PW}" -C $sql_cli_batch_mode "$@"
  else
    sqlcmd -I -d "$SRCDB_DB" -S "$SRCDB_HOST,$SRCDB_PORT" -U "${SRCDB_ARC_USER}" -P "${SRCDB_ARC_PW}" -C $sql_cli_batch_mode "$@"
  fi
}

sql_root_cli() {
  # when stdin is redirected
  # -I enable quite identified
  # -h-1 remove header and -----
  # -W remove trailing spaces
  # -s ","
  # -w width of the screen
  if [ ! -t 0 ]; then
    local sql_cli_batch_mode="-h-1 -W -s , -w 1024"
    cat <(echo "set NOCOUNT ON") - | \
    sqlcmd -I -S "$SRCDB_HOST,$SRCDB_PORT" -U "${SRCDB_ROOT_USER}" -P "${SRCDB_ROOT_PW}" -C $sql_cli_batch_mode "$@"
  else
    sqlcmd -I -S "$SRCDB_HOST,$SRCDB_PORT" -U "${SRCDB_ROOT_USER}" -P "${SRCDB_ROOT_PW}" -C $sql_cli_batch_mode "$@"
  fi
}

jdbc_root_cli() {
  # when stdin is redirected
  # -e echo sql commands
  # -n batch mode and don't save in history
  # -v don't print header and footer
  if [ ! -t 0 ]; then 
    local batch_mode="-n -v headers=false -v footers=false"
    # this is to inject \set style=csv before the acqual sql
    cat <(echo "\set style=csv") - | \
      PATH=/usr/lib/jvm/java-17-openjdk-amd64/bin:$PATH \
      CLASSPATH=$SRCDB_CLASSPATH:$CLASSPATH \
      jsqsh ${batch_mode} --jdbc-class "$SRCDB_JDBC_DRIVER" \
      --driver "$SRCDB_JSQSH_DRIVER" \
      --jdbc-url "$SRCDB_JDBC_URL" \
      --user "$SRCDB_ROOT_USER" \
      --password "$SRCDB_ROOT_PW" "$@"
  else
    PATH=/usr/lib/jvm/java-17-openjdk-amd64/bin:$PATH \
    CLASSPATH=$SRCDB_CLASSPATH:$CLASSPATH \
    jsqsh ${batch_mode} --jdbc-class "$SRCDB_JDBC_DRIVER" \
    --driver "$SRCDB_JSQSH_DRIVER" \
    --jdbc-url "$SRCDB_JDBC_URL" \
    --user "$SRCDB_ROOT_USER" \
    --password "$SRCDB_ROOT_PW" "$@"
  fi
}

jdbc_cli() {
  # when stdin is redirected
  # -e echo sql commands
  # -n batch mode and don't save in history
  # -v don't print header and footer
  if [ ! -t 0 ]; then
    local batch_mode="-n -v headers=false -v footers=false"
    cat <(echo "\set style=csv") - | \
      PATH=/usr/lib/jvm/java-17-openjdk-amd64/bin:$PATH \
      CLASSPATH=$SRCDB_CLASSPATH:$CLASSPATH \
      jsqsh ${batch_mode} --jdbc-class "$SRCDB_JDBC_DRIVER" \
      --driver "$SRCDB_JSQSH_DRIVER" \
      --jdbc-url "$SRCDB_JDBC_URL" \
      --user "$SRCDB_ARC_USER" \
      --password "$SRCDB_ARC_PW" \
      --database "$SRCDB_DB" "$@"

  else
    PATH=/usr/lib/jvm/java-17-openjdk-amd64/bin:$PATH \
    CLASSPATH=$SRCDB_CLASSPATH:$CLASSPATH \
    jsqsh ${batch_mode} --jdbc-class "$SRCDB_JDBC_DRIVER" \
    --driver "$SRCDB_JSQSH_DRIVER" \
    --jdbc-url "$SRCDB_JDBC_URL" \
    --user "$SRCDB_ARC_USER" \
    --password "$SRCDB_ARC_PW" \
    --database "$SRCDB_DB" "$@"
  fi
}

# change this for the 
port_db() {

    arcion_version

    # default user, pass, db
    export SRCDB_ARC_USER=arcsrc
    export SRCDB_ARC_PW=Passw0rd
    export SRCDB_DB=arcsrc
    export SRCDB_SCHEMA=dbo
    export SRCDB_USER_CHANGE=arcsrc

    export SRCDB_ROOT_USER=sa
    export SRCDB_ROOT_PW=Passw0rd

    # arcion parallelism
    export SRCDB_SNAPSHOT_THREADS=1
    export SRCDB_DELTA_SNAPSHOT_THREADS=1
    export SRCDB_REALTIME_THREADS=1

    # default YCSB table name
    export fq_table_name=YCSBSPARSE

    # database dependent 
    local port=${1:-1433}

    # jdbc params for ycsb and jsqsh
    if [ -n "$(netstat -an | grep -i listen | grep 1433)" ]; then
      export SRCDB_PORT=${port}
    else
      export SRCDB_PORT=$(podman port --all | grep "${port}/tcp" | head -n 1 | cut -d ":" -f 2)
    fi

    export SRCDB_HOST=127.0.0.1
    export SRCDB_YCSB_DRIVER="jdbc"
    export SRCDB_JSQSH_DRIVER="mssql2k5"
    export SRCDB_JDBC_DRIVER="com.microsoft.sqlserver.jdbc.SQLServerDriver"
    # NOTE: YCSB bug https://github.com/brianfrankcooper/YCSB/issues/1458
    # USE arcion fork otherwise cannot use ;databaseName=${DSTDB_ARC_USER}
    export SRCDB_JDBC_URL="jdbc:sqlserver://${SRCDB_HOST}:${SRCDB_PORT};database=${SRCDB_USER_CHANGE};useBulkCopyForBatchInsert=true;"   
    export SRCDB_JDBC_URL_BENCHBASE="jdbc:sqlserver://${SRCDB_HOST}:${SRCDB_PORT};database=${SRCDB_USER_CHANGE};encrypt=false;useBulkCopyForBatchInsert=true"   
    export SRCDB_JDBC_NO_REWRITE="s/useBulkCopyForBatchInsert=true/useBulkCopyForBatchInsert=false/g"
    export SRCDB_JDBC_REWRITE="s/useBulkCopyForBatchInsert=false/useBulkCopyForBatchInsert=true/g"      
    if [ -n "${ARCION_HOME}" ] && [ -d "${ARCION_HOME}/lib" ]; then 
      export SRCDB_CLASSPATH="$( find ${ARCION_HOME}/lib -name mssql*jar | paste -sd :)"
    fi
    export JSQSH_JAVA_OPTS=""

    if [ ! -x jsqsh ]; then
      export PATH=/opt/stage/bin/jsqsh-dist-3.0-SNAPSHOT/bin:$PATH
      echo "PATH=/opt/stage/bin/jsqsh-dist-3.0-SNAPSHOT/bin added"
    fi

    set_ycsb_classpath
}

# ycsb.sh requires the classpath to be in setenv.sh
set_ycsb_classpath() {
    pushd /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/bin >/dev/null || return 1
    cat >setenv.sh <<EOF
#!/usr/env/bin bash
export CLASSPATH=$SRCDB_CLASSPATH
EOF
    popd >/dev/null
}

create_ycsb_table() {
    # -e echo the command
    # -n non-interactive mode 
  heredoc_file demo/sqlserver/sql/ycsb.sql | tee -a demo/sqlserver/config/ycsb.sql | sql_cli
}

list_tables() {
  sql_cli <<EOF
SELECT table_name, table_type FROM information_schema.tables where table_type in ('BASE TABLE','VIEW') and table_schema like '${SRCDB_SCHEMA:-%}' and table_catalog like '${SRCDB_ARC_USER:-%}' order by table_name
go
EOF
}

#
#    -e replicate_io_audit_ddl \
#    -e replicate_io_audit_tbl_cons \
#    -e replicate_io_audit_tbl_schema \
#    -e REPLICATE_IO_CDC_HEARTBEAT \
list_regular_tables() {
  list_tables | \
  awk -F ',' '{print $1}' | \
  grep -v -e MSchange_tracking_history \
    -e systranschemas 
}

add_column_ycsb() {
  sql_cli <<EOF
ALTER TABLE ${fq_table_name} ADD FIELD11 TEXT NULL
go
EOF
}

drop_column_ycsb() {
  sql_cli <<EOF
ALTER TABLE ${fq_table_name} DROP COLUMN FIELD11
go
EOF
}

drop_ycsb_table() {
  sql_cli <<EOF
drop TABLE ${fq_table_name}
go
EOF
}

# can't truncate if published for replication or enabled for Change Data Capture
truncate_ycsb_table() {
  sql_cli <<EOF
truncate TABLE ${fq_table_name}
go
EOF
}

count_ycsb_table() {
  sql_cli <<EOF | head -n 1
select count(*) from ${fq_table_name}
go
EOF
# ; -m csv required for jsqsh

}

enable_cdc() {

  rm /tmp/enable_cdc.txt 2>/dev/null

  echo "enable cdc on database ${SRCDB_DB}"
  sql_root_cli <<EOF
  -- required for CDC

if not exists (select name from sys.databases where is_cdc_enabled = 1 and name in ('${SRCDB_DB}'))
  begin
    select 'EXEC sys.sp_cdc_enable_db;';  
    use ${SRCDB_DB};
    EXEC sys.sp_cdc_enable_db; 
  end
else
  select 'skip EXEC sys.sp_cdc_enable_db;';  
EOF

  # enable cdc on table ${tablename}
  list_regular_tables | while read tablename; do
    cat >>/tmp/enable_cdc.txt <<EOF
if not exists (select t.name as table_name, s.name as schema_name, t.is_tracked_by_cdc 
  from sys.tables t
  left join sys.schemas s on t.schema_id = s.schema_id
  where t.name in ('$tablename') and t.is_tracked_by_cdc=1)
  begin
    select 'EXEC sys.sp_cdc_enable_table  @source_schema = ${SRCDB_SCHEMA:-dbo}, @source_name = $tablename,  @role_name = NULL, @supports_net_changes = 0;';

    EXEC sys.sp_cdc_enable_table  
    @source_schema = '${SRCDB_SCHEMA:-dbo}',  
    @source_name   = '$tablename',  
    @role_name     = NULL,  
    @supports_net_changes = 0;
  end
else
    select 'skip EXEC sys.sp_cdc_enable_table  @source_schema = ${SRCDB_SCHEMA:-dbo}, @source_name = $tablename,  @role_name = NULL, @supports_net_changes = 0;';
EOF
  done
  if [ -s /tmp/enable_cdc.txt ]; then 
    cat /tmp/enable_cdc.txt | sql_cli
  fi
}

disable_cdc() {

  rm /tmp/disable_cdc.txt 2>/dev/null

  # disable cdc on table ${tablename}
  list_regular_tables | while read tablename; do
    cat >>/tmp/disable_cdc.txt <<EOF   
if exists (select t.name as table_name, s.name as schema_name, t.is_tracked_by_cdc 
    from sys.tables t
    left join sys.schemas s on t.schema_id = s.schema_id
    where t.name in ('$tablename') and t.is_tracked_by_cdc=1)
  begin
    select 'EXEC sys.sp_cdc_disable_table @source_schema=${SRCDB_SCHEMA:-dbo},@source_name=$tablename, @capture_instance=all;'
    EXEC sys.sp_cdc_disable_table  
      @source_schema = '${SRCDB_SCHEMA:-dbo}',  
      @source_name   = '$tablename',  
      @capture_instance = 'all'
  end
else
    select 'skip EXEC sys.sp_cdc_disable_table @source_schema=${SRCDB_SCHEMA:-dbo},@source_name=$tablename, @capture_instance=all;'
EOF
  done
  if [ -s /tmp/disable_cdc.txt ]; then 
    cat /tmp/disable_cdc.txt | sql_cli
  fi

  # disable cdc on database ${SRCDB_DB}
  sql_root_cli <<EOF
  if exists (select name from sys.databases where is_cdc_enabled = 1 and name in ('${SRCDB_DB}'))
    begin
      select 'EXEC sys.sp_cdc_disable_db;'; 
      use ${SRCDB_DB};
      EXEC sys.sp_cdc_disable_db;
    end 
  else
    select 'skip EXEC sys.sp_cdc_disable_db;'; 
EOF
}

enable_change_tracking() {
  rm /tmp/enable_change_tracking.txt 2>/dev/null

  echo "enable change tracking on database ${SRCDB_DB}"
  sql_root_cli <<EOF
  -- required for change tracking
IF NOT EXISTS (select database_id from sys.change_tracking_databases  where database_id=DB_ID('${SRCDB_DB}'))  
  begin
    select 'ALTER DATABASE ${SRCDB_DB} SET CHANGE_TRACKING = ON  (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);';
    ALTER DATABASE ${SRCDB_DB} SET CHANGE_TRACKING = ON  (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);
  end
else
    select 'skip ALTER DATABASE ${SRCDB_DB} SET CHANGE_TRACKING = ON  (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);';
EOF

  # "enable DDL tracking"
  cat ${PROG_DIR}/sql/change/change.sql | sql_cli

  # build a list of tables to enable
  list_regular_tables | while read tablename; do  
cat >>/tmp/enable_change_tracking.txt <<EOF
IF NOT EXISTS (select t.name 
    from sys.change_tracking_tables i
    left join sys.tables t
    on i.object_id = t.object_id where t.name='${tablename}')  
  begin
    select 'ALTER TABLE ${tablename} ENABLE CHANGE_TRACKING;';
    ALTER TABLE ${tablename} ENABLE CHANGE_TRACKING;
  end
else
    select 'skip ALTER TABLE ${tablename} ENABLE CHANGE_TRACKING;';
EOF
  done
  if [ -s /tmp/enable_change_tracking.txt ]; then 
    cat /tmp/enable_change_tracking.txt | sql_cli
  fi
}

disable_change_tracking() {
  rm /tmp/disable_change_tracking.txt 2>/dev/null

  echo "disable/drop trigger replicate_io_audit_ddl_trigger"
  cat <<EOF | sql_cli
IF EXISTS (select name from sys.all_sql_modules m inner join sys.triggers t on m.object_id = t.object_id where name='replicate_io_audit_ddl_trigger')
  begin
    select 'DISABLE TRIGGER "replicate_io_audit_ddl_trigger" ON DATABASE';
    DISABLE TRIGGER "replicate_io_audit_ddl_trigger" ON DATABASE;
  end
else
    select 'skip DISABLE TRIGGER "replicate_io_audit_ddl_trigger" ON DATABASE';


IF EXISTS (select name from sys.all_sql_modules m inner join sys.triggers t on m.object_id = t.object_id where name='replicate_io_audit_ddl_trigger')
  begin
    select 'drop trigger "replicate_io_audit_ddl_trigger" on DATABASE';
    drop trigger "replicate_io_audit_ddl_trigger" on DATABASE;
  end
else
    select 'skip drop trigger "replicate_io_audit_ddl_trigger" on DATABASE';
EOF

  # disable tracking on regular_tables
  list_regular_tables | while read tablename; do  
cat >>/tmp/disable_change_tracking.txt <<EOF
IF EXISTS (select t.name 
    from sys.change_tracking_tables i
    left join sys.tables t
    on i.object_id = t.object_id where t.name='${tablename}')
  begin
    select 'ALTER TABLE ${tablename} DISABLE CHANGE_TRACKING';
    ALTER TABLE ${tablename} DISABLE CHANGE_TRACKING;
  end
else
    select 'skip ALTER TABLE ${tablename} DISABLE CHANGE_TRACKING';
EOF
  done
  if [ -s /tmp/disable_change_tracking.txt ]; then 
    cat /tmp/disable_change_tracking.txt | sql_cli
  fi

  # disable change tracking on database ${SRCDB_DB} 
  sql_root_cli <<EOF
  -- required for change tracking
IF EXISTS (select database_id from sys.change_tracking_databases  where database_id=DB_ID('${SRCDB_DB}'))  
  begin
    select 'ALTER DATABASE ${SRCDB_DB} SET CHANGE_TRACKING = OFF';
    ALTER DATABASE ${SRCDB_DB} SET CHANGE_TRACKING = OFF;
  end
else
  select 'change tracking on database already disabled';
EOF

}

load_ycsb() {
  # check required param
  create_ycsb_table
  # set default params
  local y_tablename="-p table=${fq_table_name}"
  # run
  pushd /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/ >/dev/null
  JAVA_HOME=$( find /usr/lib/jvm/java-8-openjdk-* -maxdepth 0 ) \
  bin/ycsb.sh load jdbc -s -P workloads/workloada ${y_tablename} \
  -p db.driver=$SRCDB_JDBC_DRIVER \
  -p db.url=$SRCDB_JDBC_URL \
  -p db.user="$SRCDB_ARC_USER" \
  -p db.passwd="$SRCDB_ARC_PW" \
  -p db.urlsharddelim='___' \
  -p jdbc.autocommit=true \
  -p jdbc.fetchsize=10 \
  -p db.batchsize=1000 \
  -p recordcount=100000 \
  -p jdbc.batchupdateapi=true \
  -p jdbc.ycsbkeyprefix=false \
  -p insertorder=ordered \
  -p fieldcount=0 "${@}"
  
  popd >/dev/null
}

var_name() {
  local name=$1
  local table=$2
  local var_name
  var_name=y_${name}_${table}
  if [ -z "${!var_name}" ]; then var_name=y_$name; fi
  echo "${var_name}"
}

# fq_table_names
# y_threads:-1 or y_threads_dense y_threads_sparse 
# y_target:-1 or y_target_dense y_target_sparse
# y_fieldcount:-10
# y_fieldlength:-100
start_ycsb() {

  readarray -d ',' -t tablenames_array <<< "${fq_table_names:-dense,sparse}"
  pushd /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/ >/dev/null
  for tablename in ${tablenames_array[*]}; do
    echo $tablename

    local _y_threads=$(var_name "threads" "$tablename")
    local _y_target=$(var_name "target" "$tablename")
    local _y_fieldlength=$(var_name "fieldlength" "$tablename")
    local _y_fieldcount=$(var_name "fieldcount" "$tablename")
    local _y_recordcount=$(var_name "recordcount" "$tablename")

    # run
    JAVA_HOME=$( find /usr/lib/jvm/java-8-openjdk-* -maxdepth 0 ) \
    bin/ycsb.sh run jdbc -s -P workloads/workloada -p table=ycsb${tablename} \
    -p db.driver=$SRCDB_JDBC_DRIVER \
    -p db.url=$SRCDB_JDBC_URL \
    -p db.user="$SRCDB_ARC_USER" \
    -p db.passwd="$SRCDB_ARC_PW" \
    -p db.urlsharddelim='___' \
    -p jdbc.autocommit=true \
    -p jdbc.fetchsize=10 \
    -p db.batchsize=1000 \
    -p recordcount=${!_y_recordcount:-1000} \
    -p operationcount=10000000 \
    -p jdbc.batchupdateapi=true \
    -p jdbc.ycsbkeyprefix=false \
    -p insertorder=ordered \
    -p readproportion=0 \
    -p updateproportion=1 \
    -p fieldcount=${!_y_fieldcount:-10} \
    -p fieldlength=${!_y_fieldlength:-100} \
    -threads ${!_y_threads:-1} \
    -target ${!_y_target:-1} "${@}" >$PROG_DIR/logs/ycsb.$tablename.log 2>&1 &
    
    YCSB_PID=$!
    echo $YCSB_PID > $PROG_DIR/logs/ycsb.$tablename.pid
    echo "ycsb $tablename pid $YCSB_PID"  
    echo "ycsb $tablename log is at $PROG_DIR/logs/ycsb.$tablename.log"
    echo "ycsb $tablename can be killed with . ./demo/sqlserver/run-ycsb-sqlserver-source.sh; kill_recurse \$(cat \$PROG_DIR/logs/ycsb.$tablename.pid)"
    done
    popd >/dev/null

  }


# wait for the log file to exist before running tail
wait_log() {
  LOGFILE=$1
  LOG_WAIT_SEC=1
  # -f is file exists
  # -s is empty
  while [ ! -f ${LOGFILE} ] && [ ! -s ${LOGFILE} ]; do 
    sleep ${LOG_WAIT_SEC}
    echo waiting for ${LOGFILE}
  done
}

run_arcion() {
  # TODO: make this smarter
  # java -version 2>&1 | head -n 1 | awk '{print $NF}'
  JAVA_HOME=$( find /usr/lib/jvm/java-8-openjdk-* -maxdepth 0 ) \
  $ARCION_HOME/bin/$ARCION_BIN "$@"
}

# set JAVA_HOME ARCION_HOME ARCION_BIN
replicant_or_replicate() {
  export ARCION_HOME=${ARCION_HOME:-$( find /opt/stage/arcion -maxdepth 3 -name replicate -o -name replicant | sed 's|/bin/.*$||' | head -n 1)}
  
  if [ -x "$ARCION_HOME/bin/replicant" ]; then echo replicant; export ARCION_BIN=replicant; return 0; fi 
  if [ -x "$ARCION_HOME/bin/replicate" ]; then echo replicate; export ARCION_BIN=replicate; return 0; fi 
  
  echo "$ARCION_HOME/bin does not have replicant or replicate" >&2
  return 1
}

# set ARCION_VERSION
arcion_version() {
  replicant_or_replicate || return 1
  export ARCION_VERSION="$(run_arcion version 2>/dev/null | grep Version | awk -F' ' '{print $NF}')"
  export ARCION_YYMM=$(echo $ARCION_VERSION | awk -F'.' '{print $1 "." $2}')
  echo "$ARCION_VERSION $ARCION_YYMM"
}

# --clean-job
# a_repltype:-"real-time"
# a_yamldir:-"./yaml/change"
start_arcion() {
  replicant_or_replicate
  local a_repltype="${a_repltype:-"real-time"}"   # snapshot real-time full
  local a_yamldir="${a_yamldir:-"./yaml/change"}"
  local JAVA_HOME=$( find /usr/lib/jvm/java-8-openjdk-*/jre -maxdepth 0)

  if [ ! -d "${a_yamldir}" ]; then echo "$a_yamldir should be a dir." >&2; return 1; fi

  $ARCION_HOME/bin/$ARCION_BIN "${a_repltype}" \
    $(heredoc_file ${a_yamldir}/src.yaml                     >config/src.yaml        | echo config/src.yaml) \
    $(heredoc_file ${a_yamldir}/dst_null.yaml                >config/dst.yaml        | echo config/dst.yaml) \
    --general $(heredoc_file ${a_yamldir}/general.yaml       >config/general.yaml    | echo config/general.yaml) \
    --extractor $(heredoc_file ${a_yamldir}/extractor.yaml   >config/extractor.yaml  | echo config/extractor.yaml) \
    --filter $(heredoc_file ${a_yamldir}/filter.yaml         >config/filter.yaml     | echo config/filter.yaml) \
    --applier $(heredoc_file ${a_yamldir}/applier_null.yaml  >config/applier.yaml    | echo config/applier.yaml) \
    --overwrite --id $$ --replace >$PROG_DIR/logs/arcion.log 2>&1 &
  
  ARCION_PID=$!
  echo $ARCION_PID > $PROG_DIR/logs/arcion.pid
  echo "arcion pid $ARCION_PID"  
  echo "arcion log is at $PROG_DIR/logs/arcion.log"
  echo "arcion can be killed with . ./demo/sqlserver/run-ycsb-sqlserver-source.sh; kill_recurse \$(cat \$PROG_DIR/logs/arcion.pid)"

}

# change
start_change_arcion() {
  local a_repltype="${a_repltype:-"real-time"}"   # snapshot real-time full
  local a_yamldir="${a_yamldir:-"./yaml/change"}"
  enable_change_tracking
  start_arcion
}

start_cdc_arcion() {
  local a_repltype="${a_repltype-"real-time"}"   # snapshot real-time full
  local a_yamldir="${a_yamldir:-"./yaml/cdc"}"
  enable_cdc
  start_arcion
}


kill_ycsb() {
  for pid in $(ps -eo pid,command | grep -e '/bin/sh .*/ycsb.sh' | awk '{print $1}'); do 
    kill_recurse $pid
  done 
}

kill_arcion() { 
  for pid in $(ps -eo pid,command | grep -e 'sh .*replicant' -e 'sh .*replicate' | awk '{print $1}'); do
    kill_recurse $pid
  done 
}


show_arcion_error() {
  ARCION_PID=$(cat /tmp/arcion.pid)
  wait_log /opt/stage/demo/oraclerac/logs/$ARCION_PID/error_trace.log
  tail -f /opt/stage/demo/oraclerac/logs/$ARCION_PID/error_trace.log
}

show_arcion_trace() {
  ARCION_PID=$(cat /tmp/arcion.pid)
  wait_log /opt/stage/demo/oraclerac/logs/$ARCION_PID/trace.log
  tail -f /opt/stage/demo/oraclerac/logs/$ARCION_PID/trace.log
}


# Parameters
#   YCSB_TARGET=${1:-0}
#   SVC_NAME=${2:-cdb_svc}
restart_ycsb() {
  while [ 1 ]; do
      wait_log /var/tmp/ycsb.run.tps1.$$
      tail -f /var/tmp/ycsb.run.tps1.$$ | awk '/^Error in processing update to table: usertablejava.sql.SQLException: Closed Statement/ {print "Error"; exit 1} {print $0}'
      RC=${PIPESTATUS[1]}
      if [ "$RC" != 0 ]; then 
          echo "needs restart"; 
          set -x
          kill $(cat /tmp/ycsb.$$.pid)
          while [ -n "$(ps --no-headers $(cat /tmp/ycsb.$$.pid))" ]; do
            kill $(cat /tmp/ycsb.$$.pid)
            sleep 1
            echo "waiting clean up of $(cat /tmp/ycsb.$$.pid)" 
          done
          figlet Restarting YCSB
          start_ycsb "$@"
          set +x
      else
          break
      fi 
  done
}

status_database() {

cat <<EOF | jdbc_root_cli

-- show catalog
select name, suser_sname(owner_sid) "owner_name", is_cdc_enabled, is_change_feed_enabled, is_published, is_encrypted from sys.databases
where name in ('arcsrc')
go


-- sql server agent 4,running
SELECT dss.[status], dss.[status_desc]
FROM   sys.dm_server_services dss
WHERE  dss.[servicename] LIKE N'SQL Server Agent (%';
GO


-- table qualifier
-- show tables in cdc
select t.name as table_name, s.name as schema_name, t.is_tracked_by_cdc 
from sys.tables t
left join sys.schemas s on t.schema_id = s.schema_id
where t.name in ('ycsbsparse')
go

-- show tables in change tracking
select i.*,t.name 
from sys.change_tracking_tables i
left join sys.tables t
on i.object_id = t.object_id 
go

EOF

}


port_db
