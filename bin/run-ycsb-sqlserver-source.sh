#!/usr/env/bin/bash

# heredoc_file filename 
heredoc_file() {
    eval "$( echo -e '#!/usr/bin/env bash\ncat << EOF_EOF_EOF' | cat - $1 <(echo -e '\nEOF_EOF_EOF') )"    
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

    #
    export SRCDB_SNAPSHOT_THREADS=1
    export SRCDB_DELTA_SNAPSHOT_THREADS=1
    export SRCDB_REALTIME_THREADS=1

    # default YCSB table name
    export fq_table_name=YCSBSPARSE

    # database dependent 
    local port=${1:-1433}

    export SRCDB_PORT=$(podman port --all | grep "${port}/tcp" | head -n 1 | cut -d ":" -f 2)
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

jdbc_root_cli() {
    export CLASSPATH=$SRCDB_CLASSPATH:$CLASSPATH
    jsqsh --jdbc-class "$SRCDB_JDBC_DRIVER" \
    --driver "$SRCDB_JSQSH_DRIVER" \
    --jdbc-url "$SRCDB_JDBC_URL" \
    --user "$SRCDB_ROOT_USER" \
    --password "$SRCDB_ROOT_PW" "$@"
}

jdbc_cli() {
    export CLASSPATH=$SRCDB_CLASSPATH:$CLASSPATH
    jsqsh --jdbc-class "$SRCDB_JDBC_DRIVER" \
    --driver "$SRCDB_JSQSH_DRIVER" \
    --jdbc-url "$SRCDB_JDBC_URL" \
    --user "$SRCDB_ARC_USER" \
    --password "$SRCDB_ARC_PW" "$@"
}

# svc_name
create_ycsb_table() {
    # -e echo the command
    # -n non-interactive mode 
  heredoc_file sql/ycsb.sql | tee -a config/ycsb.sql | jdbc_cli -n -e
}

add_column_ycsb() {
  jdbc_cli -n -e<<EOF
ALTER TABLE ${fq_table_name} 
ADD FIELD11 TEXT NULL
go
EOF
}

drop_column_ycsb() {
  jdbc_cli -n -e<<EOF
ALTER TABLE ${fq_table_name} 
DROP COLUMN FIELD11
go
EOF
}

drop_ycsb_table() {
    # -e echo the command
    # -n non-interactive mode 
  jdbc_cli -n -e<<EOF
drop TABLE ${fq_table_name}
go
EOF
}

truncate_ycsb_table() {
    # -e echo the command
    # -n non-interactive mode 
  jdbc_cli -n -e<<EOF
truncate TABLE ${fq_table_name}
go
EOF
}

count_ycsb_table() {
    # -e echo the command
    # -n non-interactive mode 
  jdbc_cli -n -v headers=false -v footers=false<<EOF
select count(*) from ${fq_table_name}; -m csv
EOF
}

enable_cdc() {

jdbc_cli -n -v headers=false -v footers=false <<"EOF"
\tables --type=TABLE | awk -F '[| ]+' '{print $3}'
EXEC sys.sp_cdc_enable_table  
@source_schema = N'dbo',  
@source_name   = N'MyTable',  
@role_name     = NULL,  
@supports_net_changes = 1 or 0
EOF
}

enable_change_tracking() {
echo "me"
}

load_ycsb() {
  # check required param
  create_ycsb_table
  # set default params
  local y_tablename="-p table=${fq_table_name}"
  # run
  set -x 
  pushd /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/ >/dev/null
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
  
  set +x
  popd >/dev/null
}

start_ycsb() {
  local y_tablename="-p table=${fq_table_name}"
  # run
  set -x 
  pushd /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/ >/dev/null
  bin/ycsb.sh run jdbc -s -P workloads/workloada ${y_tablename} \
  -p db.driver=$SRCDB_JDBC_DRIVER \
  -p db.url=$SRCDB_JDBC_URL \
  -p db.user="$SRCDB_ARC_USER" \
  -p db.passwd="$SRCDB_ARC_PW" \
  -p db.urlsharddelim='___' \
  -p jdbc.autocommit=true \
  -p jdbc.fetchsize=10 \
  -p db.batchsize=1000 \
  -p recordcount=100000 \
  -p operationcount=10000000 \
  -p jdbc.batchupdateapi=true \
  -p jdbc.ycsbkeyprefix=false \
  -p insertorder=ordered \
  -threads 1 \
  -target 1 "${@}"
   
  set +x
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

# set JAVA_HOME ARCION_HOME ARCION_BIN
replicant_or_replicate() {
  export JAVA_HOME=${JAVA_HOME:-$( find /usr/lib/jvm/java-8-openjdk-*/jre -maxdepth 0)}
  export ARCION_HOME=${ARCION_HOME:-$( find /opt/stage/arcion -maxdepth 3 -name replicate -o -name replicant | sed 's|/bin/.*$||' | head -n 1)}
  
  if [ -x "$ARCION_HOME/bin/replicant" ]; then echo replicant; export ARCION_BIN=replicant; return 0; fi 
  if [ -x "$ARCION_HOME/bin/replicate" ]; then echo replicate; export ARCION_BIN=replicate; return 0; fi 
  
  echo "$ARCION_HOME/bin does not have replicant or replicate" >&2
  return 1
}

# set ARCION_VERSION
arcion_version() {
  replicant_or_replicate || return 1
  export ARCION_VERSION="$($ARCION_HOME/bin/$ARCION_BIN version 2>/dev/null | grep Version | awk -F' ' '{print $NF}')"
  export ARCION_YYMM=$(echo $ARCION_VERSION | awk -F'.' '{print $1 "." $2}')
  echo "$ARCION_VERSION $ARCION_YYMM"
}


# fetch-schemas does not work on 23.05.31.29 and 23.05.31.31
fetch_schema() {
  replicant_or_replicate || return 1

  set -x
  $ARCION_HOME/bin/$ARCION_BIN fetch-schemas src_pdb_23.05.yaml \
    --filter filter.yaml \
    --output-file oracle_schema.yaml \
    --fetch-row-count-estimate
  set +x
}

# --clean-job
start_arcion() {
  replicant_or_replicate
  local YAML_DIR="${1:-"./yaml/change_tracking"}"
  local REPL_TYPE="${2:-"real-time"}"   # snapshot real-time full
  local JAVA_HOME=$( find /usr/lib/jvm/java-8-openjdk-*/jre -maxdepth 0)
  set -x 
  $ARCION_HOME/bin/$ARCION_BIN \
    ${REPL_TYPE} \
    $(heredoc_file ${YAML_DIR}/src.yaml                     >config/src.yaml        | echo config/src.yaml) \
    $(heredoc_file ${YAML_DIR}/dst_null.yaml                >config/dst.yaml        | echo config/dst.yaml) \
    --general $(heredoc_file ${YAML_DIR}/general.yaml       >config/general.yaml    | echo config/general.yaml) \
    --extractor $(heredoc_file ${YAML_DIR}/extractor.yaml   >config/extractor.yaml  | echo config/extractor.yaml) \
    --filter $(heredoc_file ${YAML_DIR}/filter.yaml         >config/filter.yaml     | echo config/filter.yaml) \
    --applier $(heredoc_file ${YAML_DIR}/applier_null.yaml  >config/applier.yaml    | echo config/applier.yaml) \
    --overwrite --id $$ --replace
  set +x
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


port_db
