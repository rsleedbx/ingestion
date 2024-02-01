#!/usr/env/bin/bash

port_db() {
    local port=${1:-1433}
  if [ -z "${jdbc_port}" ]; then export jdbc_port=$(podman port --all | grep "${port}/tcp" | head -n 1 | cut -d ":" -f 2); fi
  if [ -z "${jdbc_class}" ]; then export jdbc_class="org.mariadb.jdbc.Driver"; fi
  if [ -z "${jsqsh_driver}" ]; then export jsqsh_driver="mysql"; fi
  if [ -z "${jdbc_url}" ]; then export jdbc_url="jdbc:mysql://127.0.0.1:${jdbc_port}/${y_dbname}?permitMysqlScheme&restrictedAuth=mysql_native_password&rewriteBatchedStatements=true"; fi
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

start_arcion() {
  replicant_or_replicate || return 1

  $ARCION_HOME/bin/$ARCION_BIN real-time src.yaml dst_null.yaml \
    --overwrite --id $$ --replace \
    --general general.yaml \
    --extractor extractor.yaml \
    --filter filter.yaml \
    --applier applier_null.yaml \
    &

  echo $$ >/tmp/arcion.pid
  echo arcion pid=$$
}

start_arcion_pdb_2305() {
  local JAVA_HOME=$( find /usr/lib/jvm/java-8-openjdk-*/jre -maxdepth 0)
  local ARCION_HOME=/opt/stage/arcion/replicate-cli-23.05.31.29  
  local ARCION_BIN=replicate
  local ID=2305pdb

  replicant_or_replicate || return 1

  if [[ "$ARCION_YYMM" < "23.09" ]] && [[ -f oracle_schema.yaml ]]; then
    export SRC_SCHEMAS="--src-schemas oracle_schema.yaml"
  else
    echo "--src-schemas oracle_schema.yaml required but YAML is missing" >&2
  fi

  
  $ARCION_HOME/bin/$ARCION_BIN real-time src_pdb_23.05.yaml dst_null.yaml \
    --overwrite --id ${ID} --replace \
    --general general.yaml \
    --extractor extractor_pdb_2305.yaml \
    --filter filter.yaml \
    --applier applier_null.yaml \
    ${SRC_SCHEMAS} &
  PID=$!
  echo $PID >/tmp/arcion.pid
  echo arcion pid=$PID
}


start_arcion_cdb_2305() {
  local JAVA_HOME=$( find /usr/lib/jvm/java-8-openjdk-*/jre -maxdepth 0)
  local ARCION_HOME=/opt/stage/arcion/replicate-cli-23.05.31.29  
  local ARCION_BIN=replicate
  local ID=2305cdb

  replicant_or_replicate || return 1

  if [[ "$ARCION_YYMM" < "23.09" ]] && [[ -f oracle_schema.yaml ]]; then
    export SRC_SCHEMAS="--src-schemas oracle_schema.yaml"
  else
    echo "--src-schemas oracle_schema.yaml required but YAML is missing" >&2
  fi

  
  $ARCION_HOME/bin/$ARCION_BIN real-time src_cdb_23.05.yaml dst_null.yaml \
    --overwrite --id ${ID} --replace --clean-job \
    --general general.yaml \
    --extractor extractor.yaml \
    --filter filter.yaml \
    --applier applier_null.yaml \
    ${SRC_SCHEMAS} &
  PID=$!
  echo $PID >/tmp/arcion.pid
  echo arcion pid=$PID
}

start_arcion_cdb_2309() {
  local JAVA_HOME=$( find /usr/lib/jvm/java-8-openjdk-*/jre -maxdepth 0)
  local ARCION_HOME=/opt/stage/arcion/23.09.29.11
  local ARCION_BIN=replicant
  local ID=2309CDB
  
  $ARCION_HOME/bin/$ARCION_BIN real-time src_cdb_23.09.yaml dst_null.yaml \
    --overwrite --id ${ID} --replace \
    --general general.yaml \
    --extractor extractor.yaml \
    --filter filter.yaml \
    --applier applier_null.yaml \
    &
  PID=$!
  echo $PID >/tmp/arcion.pid
  echo arcion pid=$PID
}

start_arcion_pdb_2309() {
  local JAVA_HOME=$( find /usr/lib/jvm/java-8-openjdk-*/jre -maxdepth 0)
  local ARCION_HOME=/opt/stage/arcion/23.09.29.11
  local ARCION_BIN=replicant
  local ID=2309pdb
  
  $ARCION_HOME/bin/$ARCION_BIN real-time src_pdb_23.09.yaml dst_null.yaml \
    --overwrite --id ${ID} --replace \
    --general general.yaml \
    --extractor extractor.yaml \
    --filter filter.yaml \
    --applier applier_null.yaml \
    &
  PID=$!
  echo $PID >/tmp/arcion.pid
  echo arcion pid=$PID
}


start_arcion_ss() {
  export JAVA_HOME=$( find /usr/lib/jvm/java-8-openjdk-*/jre -maxdepth 0)
  export ARCION_HOME=/opt/stage/arcion/replicate-cli-23.05.31.29
  pushd -n /opt/stage/demo/oraclerac
  $ARCION_HOME/bin/replicate real-time src.yaml dst_null.yaml \
    --overwrite --id $$ --replace \
    --general general.yaml \
    --extractor extractor.yaml \
    --filter filter.yaml \
    --applier applier_null.yaml &
  popd
  echo $$ >/tmp/arcion.pid
  echo arcion pid=$$
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


# create and load ycsb

load_ycsb_cdb() {
  if [ -z "${svc_name}" ]; then local svc_name=cdb_svc; fi
  if [ -z "${y_tablename}" ]; then local y_tablename="usertablecdb"; fi

  load_ycsb
}

load_ycsb_pdb() {
  if [ -z "${svc_name}" ]; then local svc_name=pdb1_svc; fi
  if [ -z "${y_tablename}" ]; then local y_tablename="usertablepdb"; fi

  load_ycsb
}

# svc_name
create_ycsb_table() {
  # set default params
  if [ -z "${y_dbname}" ]; then local y_dbname="arcsrc"; fi  
  if [ -z "${y_tablename}" ]; then local y_tablename="usertable"; fi
  if [ -z "${y_port}" ]; then local y_port="$(port_mysql)"; fi
  # check required param
  if [ -z "${y_dbname}" ]; then echo "y_dbname not defined"; return 1; fi  
  if [ -z "${y_port}" ]; then echo "y_port not defined"; return 1; fi    
  # run
  port_mysql
  set -x
  jsqsh -n --jdbc-class "org.mariadb.jdbc.Driver" \
  --driver mysql \
  --jdbc-url "jdbc:mysql://127.0.0.1:${jdbc_port}/arcsrc?permitMysqlScheme&restrictedAuth=mysql_native_password&rewriteBatchedStatements=true" \
  --user "arcsrc" \
  --password "Passw0rd" <<EOF
CREATE TABLE IF NOT EXISTS usertable (
    YCSB_KEY INT PRIMARY KEY,
    FIELD0 TEXT, FIELD1 TEXT,
    FIELD2 TEXT, FIELD3 TEXT,
    FIELD4 TEXT, FIELD5 TEXT,
    FIELD6 TEXT, FIELD7 TEXT,
    FIELD8 TEXT, FIELD9 TEXT,
    TS TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    INDEX (TS)
);
desc usertable;
EOF
  set +x
}

load_ycsb() {
  # check required param
  create_ycsb_table
  # set default params
  if [ -n "${y_tablename}" ]; then local y_tablename="-p table=${y_tablename}'"; fi
  # run
  port_mysql
  set -x 
  pushd /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/ >/dev/null
  bin/ycsb.sh load jdbc -s -P workloads/workloada ${y_tablename} \
  -p db.driver=$jdbc_class \
  -p db.url="jdbc:mysql://127.0.0.1:${jdbc_port}/arcsrc?permitMysqlScheme&restrictedAuth=mysql_native_password&rewriteBatchedStatements=true" \
  -p db.user="arcsrc" \
  -p db.passwd="Passw0rd" \
  -p jdbc.autocommit=true \
  -p jdbc.fetchsize=10 \
  -p db.batchsize=1000 \
  -p recordcount=100000 \
  -p jdbc.batchupdateapi=true \
  -p jdbc.ycsbkeyprefix=false \
  -p insertorder=ordered
  
  set +x
  popd >/dev/null
}

# start YCSB 

start_ycsb_pdb() {
  if [ -z "${svc_name}" ]; then local svc_name=pdb1_svc; fi
  if [ -z "${y_tablename}" ]; then local y_tablename="usertablepdb"; fi
  
  start_ycsb
}

start_ycsb_cdb() {
  if [ -z "${svc_name}" ]; then local svc_name=cdb_svc; fi
  if [ -z "${y_tablename}" ]; then local y_tablename="usertablecdb"; fi
  
  start_ycsb
}


start_ycsb() {

  # set default params
  if [ -z "$svc_name" ]; then echo "setting svc_name=arcsrc"; local svc_name=arcsrc; fi
  if [ -z "$y_target" ]; then echo "setting y_target=1"; local y_target=1; fi
  if [ -z "$y_thread" ]; then echo "setting y_thread=1"; local y_thread=1; fi
  # use param in the call
  if [ -n "${y_tablename}" ]; then local y_tablename="-p table=${y_tablename}"; fi
  if [ -n "${y_target}" ]; then local y_target="-target ${y_target}"; fi
  if [ -n "${y_thread}" ]; then local y_thread="-threads ${y_thread}"; fi
  # check required param
  if [ -z "$svc_name" ]; then echo "$2 svc_name must be set" >&2; return 1; fi
  rm /var/tmp/ycsb.run.tps1.$$ /tmp/ycsb.$$.pid 2>/dev/null
  pushd /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/
  port_mysql
  ./bin/ycsb.sh run jdbc -s -P workloads/workloada ${y_tablename} \
  -p db.url="jdbc:mysql://127.0.0.1:${jdbc_port}/arcsrc?permitMysqlScheme&restrictedAuth=mysql_native_password&rewriteBatchedStatements=true" \
  -p db.user="arcsrc" \
  -p db.passwd="Passw0rd" \
  -p jdbc.autocommit=true \
  -p jdbc.fetchsize=10 \
  -p db.batchsize=1000 \
  -p recordcount=100000 \
  -p operationcount=10000000 \
  -p jdbc.batchupdateapi=true \
  -p jdbc.ycsbkeyprefix=false \
  -p insertorder=ordered \
  -p jdbc.prependtimestamp=true

  #>/var/tmp/ycsb.run.tps1.$$ 2>&1
  YCSB_PID=$!
  echo ${YCSB_PID} > /tmp/ycsb.$$.pid 
  echo "YCSB_PID=$YCSB_PID"
  echo "Check the log at /var/tmp/ycsb.run.tps1.$$"
  popd
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

# show user id connected to the instances
show_connections() {
  ssh oracle@ol7-19-rac1 ". ~/.bash_profile; sqlplus -s / as sysdba" <<EOF
  set markup csv on
  -- show who connect to which node
  select i.host_name, s.username from 
    gv\$session s join
    gv\$instance i on (i.inst_id=s.inst_id)
  where 
    username is not null;
EOF
}


switch_service_cdb() {
  ssh oracle@ol7-19-rac1 ". ~/.bash_profile; srvctl status service -db cdbrac -s cdb_svc" | awk '{print $NF}' > /tmp/cdb_svc_running_instance.$$.txt

  ssh oracle@ol7-19-rac1 ". ~/.bash_profile; srvctl config service -d cdbrac -s cdb_svc" > /tmp/cdb_svc_config_service.$$.txt

  grep "^Preferred instances:" /tmp/cdb_svc_config_service.$$.txt | awk '{print $NF}' | tr ',' '\n' > /tmp/cdb_svc_preferred_instances.$$.txt

  grep "^Available instances:" /tmp/cdb_svc_config_service.$$.txt | awk '{print $NF}' | tr ',' '\n'> /tmp/cdb_svc_available_instances.$$.txt

  cat /tmp/cdb_svc_preferred_instances.$$.txt /tmp/cdb_svc_available_instances.$$.txt | sort -u > /tmp/cdb_svc_all_instances.$$.txt

  # show next node to run the service
  new_inst=$(comm -23 /tmp/cdb_svc_all_instances.$$.txt /tmp/cdb_svc_running_instance.$$.txt | head -n 1)

  if [ -n "${new_inst}" ]; then 
      old_inst=$(cat /tmp/cdb_svc_running_instance.$$.txt)
      ssh oracle@ol7-19-rac1 ". ~/.bash_profile; srvctl relocate service -db cdbrac -service cdb_svc -oldinst ${old_inst} -newinst ${new_inst} -stopoption IMMEDIATE -force -verbose; srvctl status service -db cdbrac -s cdb_svc"
  fi

  show_connections | grep -i arcsrc
}

show_status_service() {
  ssh oracle@ol7-19-rac1 ". ~/.bash_profile; srvctl status service -db cdbrac"
}

switch_service_pdb() {
  local SVC_NAME=pdb1_svc

  ssh oracle@ol7-19-rac1 ". ~/.bash_profile; srvctl status service -db cdbrac -s ${SVC_NAME}" | awk '{print $NF}' > /tmp/${SVC_NAME}_running_instance.$$.txt

  ssh oracle@ol7-19-rac1 ". ~/.bash_profile; srvctl config service -d cdbrac -s ${SVC_NAME}" > /tmp/${SVC_NAME}_config_service.$$.txt

  grep "^Preferred instances:" /tmp/${SVC_NAME}_config_service.$$.txt | awk '{print $NF}' | tr ',' '\n' > /tmp/${SVC_NAME}_preferred_instances.$$.txt

  grep "^Available instances:" /tmp/${SVC_NAME}_config_service.$$.txt | awk '{print $NF}' | tr ',' '\n'> /tmp/${SVC_NAME}_available_instances.$$.txt

  cat /tmp/${SVC_NAME}_preferred_instances.$$.txt /tmp/${SVC_NAME}_available_instances.$$.txt | sort -u > /tmp/${SVC_NAME}_all_instances.$$.txt

  # show next node to run the service
  new_inst=$(comm -23 /tmp/${SVC_NAME}_all_instances.$$.txt /tmp/${SVC_NAME}_running_instance.$$.txt | head -n 1)

  if [ -n "${new_inst}" ]; then 
      old_inst=$(cat /tmp/${SVC_NAME}_running_instance.$$.txt)
      ssh oracle@ol7-19-rac1 ". ~/.bash_profile; srvctl relocate service -db cdbrac -service ${SVC_NAME} -oldinst ${old_inst} -newinst ${new_inst} -stopoption IMMEDIATE -force -verbose; srvctl status service -db cdbrac -s ${SVC_NAME}"
  fi

  show_connections | grep -i arcsrc
}


