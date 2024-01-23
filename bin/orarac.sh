#!/usr/env/bin/bash

# wait for the log file to exist before running tail
wait_log() {
  LOGFILE=$1
  LOG_WAIT_SEC=1
  # -f is file exists
  # -s is empty
  while [ ! -f ${LOGFILE} ] && [ ! -s ${LOGFILE} ]; do sleep ${LOG_WAIT_SEC}; done
}

# restart YCSB 
start_ycsb() {
    pushd /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/
    bin/ycsb.sh run jdbc -s -P workloads/workloada -p db.driver=oracle.jdbc.OracleDriver -p db.url="jdbc:oracle:thin:@//ol7-19-scan:1521/cdb_svc" -p db.user="c##arcsrc" -p db.passwd="Passw0rd" -p db.batchsize=1000  -p jdbc.fetchsize=10 -p jdbc.autocommit=true -p jdbc.batchupdateapi=true -p db.batchsize=1000 -p recordcount=100000 -p jdbc.ycsbkeyprefix=false -p insertorder=ordered -p operationcount=100000 -p readproportion=0 -p updateproportion=1 -threads 1 -target 1 >/var/tmp/ycsb.run.tps1.$$ 2>&1 &
    YCSB_PID=$!
    echo "YCSB_PID=$YCSB_PID"
    echo "Check the log at /var/tmp/ycsb.run.tps1.$$"
    popd
}

restart_ycsb() {
    wait_log "/var/tmp/ycsb.run.tps1.$$"

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

