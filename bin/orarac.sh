#!/usr/env/bin/bash

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

start_arcion() {
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



# restart YCSB 
start_ycsb() {
  YCSB_TARGET=${1:-0}

  rm /var/tmp/ycsb.run.tps1.$$
  /tmp/ycsb.$$.pid
  pushd -n /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/
  bin/ycsb.sh run jdbc -s -P workloads/workloada -p db.driver=oracle.jdbc.OracleDriver -p db.url="jdbc:oracle:thin:@//ol7-19-scan:1521/cdb_svc" -p db.user="c##arcsrc" -p db.passwd="Passw0rd" -p db.batchsize=1000  -p jdbc.fetchsize=10 -p jdbc.autocommit=true -p jdbc.batchupdateapi=true -p db.batchsize=1000 -p recordcount=100000 -p jdbc.ycsbkeyprefix=false -p insertorder=ordered -p operationcount=10000000 -p readproportion=0 -p updateproportion=1 -threads 1 -target ${YCSB_TARGET} >/var/tmp/ycsb.run.tps1.$$ 2>&1 &
  YCSB_PID=$!
  echo ${YCSB_PID} > /tmp/ycsb.$$.pid 
  echo "YCSB_PID=$YCSB_PID"
  echo "Check the log at /var/tmp/ycsb.run.tps1.$$"
  popd
}

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

switch_service() {
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


