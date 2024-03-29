#!/usr/bin/env bash

if [ -z "${BASH_SOURCE}" ]; then 
  echo "Please invoke using bash" 
  exit 1
fi

PROG_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
(return 0 2>/dev/null) && export SCRIPT_SOURCED=1 || export SCRIPT_SOURCED=0

# load the libary
. ${PROG_DIR}/../../bin/utils.sh
. ${PROG_DIR}/../../bin/install-postgres.sh
. ${PROG_DIR}/../../libsh/ini_jdbc.sh

export ARCION_BASEDIR=/opt/stage/arcion

send_command_tmux_window() {
  local session_name=${1}
  local window_name=${2}
  local command=${3}
  tmux respawn-window -t ${session_name}:${window_name} -k 
  if [ -n "$command" ]; then 
    tmux send-keys -t ${session_name}:${window_name} "${command}" enter
  fi
}

nine_char_id() {
    printf "%09x\n" "$(( $(date +%s%N) / 100000000 ))"
}



#
kill_recurse() {
    if [ -z "${1}" ]; then return 0; fi
    echo kill $1
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

load_dense_data_cnt() {
  local TABLE_COUNT=${1:-${TABLE_COUNT:-1}}
  local TABLE_COUNTSTART=${2:-1}
  local y_fieldcount=${y_fieldcount:-10}
  local y_fieldlength=${y_fieldlength:-100}
  local y_recordcount=${y_recordcount:-100K}
  local y_fillstart=${y_fillstart:-1}
  local y_fillend=${y_fillend:-${y_fieldcount}}
  local y_tabletype=dense

  echo -n "starting dense load. $YCSB_LOG_DIR/ycsbdense.load.log"
  rm $YCSB_LOG_DIR/ycsbdense.load.log 2>/dev/null
  touch $YCSB_LOG_DIR/ycsbdense.load.log
  for i in $(seq $TABLE_COUNTSTART $TABLE_COUNT); do
    echo -n " $i"
    load_dense_data $i >> $YCSB_LOG_DIR/ycsbdense.load.log 2>&1
  done
  echo ""
}

load_sparse_data_cnt() {
  local TABLE_COUNT=${1:-${TABLE_COUNT:-1}}
  local TABLE_COUNTSTART=${2:-1}
  local y_fieldcount=${y_fieldcount:-10}
  local y_fieldlength=${y_fieldlength:-100} 
  local y_recordcount=${y_recordcount:-1M}
  local y_fillstart=${y_fillstart:-0}
  local y_fillend=${y_fillend:-0}
  local y_tabletype=sparse

  echo -n "starting sparse load. $YCSB_LOG_DIR/ycsbsparse.load.log"
  rm $YCSB_LOG_DIR/ycsbsparse.load.log 2>/dev/null
  touch $YCSB_LOG_DIR/ycsbsparse.load.log
  for i in $(seq $TABLE_COUNTSTART $TABLE_COUNT); do
    echo -n " $i"
    load_dense_data $i >> $YCSB_LOG_DIR/ycsbsparse.load.log 2>&1
  done
  echo ""
}


# return env_var
#  table_name
#  record_count
#  field_count
convert_table_stat_to_var() {
  local table_stat_array

  readarray -d ',' -t table_stat_array < <(echo -n "$1")
  table_name=${table_stat_array[0],,} # lowercase the tablename
  record_start=${table_stat_array[1]} 
  record_end=${table_stat_array[2]} 
  field_count=${table_stat_array[3]} 
  record_count=0

  if [[ ${table_stat_array[1]} == "NULL" ]] || [[ -z "${table_stat_array[1]}" ]]; then
    record_start=0
  fi   

  if [[ ${table_stat_array[2]} == "NULL" ]] || [[ -z "${table_stat_array[2]}" ]]; then
    record_count=0
  else
    record_count=$(( table_stat_array[2] - record_start + 1 ))
  fi   
  
  if [[ ${table_stat_array[3]} == "NULL" ]] || [[ -z "${table_stat_array[3]}" ]]; then
    field_count=0
  else
    field_count=${table_stat_array[3]} 
  fi
}

load_dense_data() {
  local TABLE_INST=${1:-${TABLE_INST:-1}}

  if [ -z "$(command -v bcp)" ]; then export PATH=/opt/mssql-tools18/bin:$PATH; fi

    local TABLE_INST_NAME=$(sf_to_name $TABLE_INST)
    local y_insertstart
    local table_field_cnt

    local y_fieldcount=$( numfmt --from=auto  "$y_fieldcount" )
    local y_fillstart=$( numfmt --from=auto "$y_fillstart" )
    local y_fillend=$( numfmt --from=auto "$y_fillend" )
    local y_fieldlength=$( numfmt --from=auto "$y_fieldlength" )
    local y_recordcount=$( numfmt --from=auto "$y_recordcount" )
    local progress_interval_rows=$(( y_recordcount / 10 ))

    echo "Starting type=${y_tabletype} inst=$TABLE_INST" 

    # return table_name, record_count, field_count, 
    local table_name
    local record_start=0
    local record_end=0
    local record_count=0
    local field_count=10
    table_stat_array=$(cat $CFG_DIR/list_table_counts.csv 2>/dev/null | grep "^YCSB${y_tabletype^^}${TABLE_INST_NAME},")
    convert_table_stat_to_var "$table_stat_array"

    # create table if not already exists
    if [ -z "${table_stat_array}" ]; then
      heredoc_file ${PROG_DIR}/sql/03_usertable.sql > ${CFG_DIR}/03_ycsb${y_tabletype}.sql 
      sql_cli < ${CFG_DIR}/03_ycsb${y_tabletype}.sql
      echo "${CFG_DIR}/03_ycsb${y_tabletype}.sql" 
      table_field_cnt=${y_fieldcount}
    else
      echo "skip table create"
    fi

    table_field_cnt=${table_field_cnt:-${field_count}}
    if [ -z "$table_field_cnt" ]; then 
      echo "error: table schema missing to determine the field count. run list_table_counts" >&2
      return 1;
    fi

    # table did not exist or 
    if [[ -z "${table_stat_array}" || ${record_count} == 0 ]] || 
       [[ -n "${table_stat_array}" && ${y_recordcount} -gt ${record_count} && ${y_fieldcount} -eq ${table_field_cnt} ]]; then
      
      # start from the end of existing records (assume YCSB_KEY started at 0)
      y_insertstart=$record_count
      echo "inserting insertstart=$y_insertstart insert ends at ycsb_key=$(( $y_recordcount - 1 ))"

      echo "y_fieldcount=$y_fieldcount y_fillstart=$y_fillstart y_fillend=$y_fillend"

      datafile=$(mktemp -p $LOG_DIR)

      # prepare data file
      # the following env vars are used
      # local y_fillstart=$( numfmt --from=auto ${y_fillstart:-1} )
      # local y_fillend=$( numfmt --from=auto ${y_fillend:-3} )
      # local y_fieldcount=$( numfmt --from=auto ${y_fieldcount:-10} )
      # local y_fieldlength=$( numfmt --from=auto ${y_fieldlength:-5} )
      # local y_insertstart=$( numfmt --from=auto ${y_insertstart:-0} )
      # local y_recordcount=$( numfmt --from=auto ${y_recordcount:-10} )

      local chunk_size=1000000  # 1M
      local chunk_insertstart=${y_insertstart}
      local current_chunk_size=$(( y_recordcount - chunk_insertstart ))
      echo "$chunk_insertstart < $y_recordcount"
      while (( chunk_insertstart < y_recordcount )); do
        echo "current_chunk_size=$current_chunk_size ($y_recordcount - $chunk_insertstart)"
        if (( current_chunk_size > chunk_size )); then 
          chunk_recordcount=$(( chunk_insertstart + chunk_size )) 
        else 
          chunk_recordcount=$(( chunk_insertstart + current_chunk_size )) 
        fi
        echo "starting chunk $chunk_insertstart to $chunk_recordcount"
        make_ycsb_dense_data $datafile ${TABLE_INST}
        echo "data file to be purged ${datafile}"
        
        # database specific
	      bulk_load
        echo "log at ${LOG_DIR}/03_${y_tabletype}table.log"

        # delete datafile
        rm $datafile
        # move to the next chunk
        chunk_insertstart=$(( chunk_insertstart + chunk_size ))
        current_chunk_size=$(( y_recordcount - chunk_insertstart ))
      done
      echo "Finished dense table $TABLE_INST" 
    else
      echo "skip load need existing count ${y_recordcount} -gt ${record_count} && field ${y_fieldcount} -eq ${table_field_cnt} "
    fi
}

# make a data file in $LOG_DIR
make_ycsb_dense_data() {
    # process params
    local param
    local -i params_processed=0
    while [[ $# -gt 0 ]]; do
      [ "${1:0:1}" != '-' ] && break  # stop on first char without leading - 0:1=starting 0 for length 1 
      [ "${1}" = '--' ] && break      # stop on --      
      param="$1"; shift; ((params_processed++)) # process parameter
      case "$param" in
        -fs|--fillstart) local y_fillstart="$1"; shift; ((params_processed++)); ;;
        -fe|--fillend) local y_fillend="$1"; shift; ((params_processed++)); ;;
        -fc|--fieldcount) local y_fieldcount="$1"; shift; ((params_processed++)); ;;
        -fl|--fieldlength) local y_fieldlength="$1"; shift; ((params_processed++)); ;;
        -is|--insertstart) local chunk_insertstart="$1"; shift; ((params_processed++)); ;;
        -rc|--recordcount) local chunk_recordcount="$1"; shift; ((params_processed++)); ;;
        -df|--datafile) local datafile="$1"; shift; ((params_processed++)); ;;
        *) echo "unknown flag '$param'"; return 1; ;;
      esac
    done

    # create tempfile
    local datafile=${datafile:-$(mktemp -p ${YCSB_LOG_DIR})}
    # convert KMBGT suffix to numeric
    local y_fillstart=$( numfmt --from=auto ${y_fillstart:-1} )
    local y_fillend=$( numfmt --from=auto ${y_fillend:-3} )
    local y_fieldcount=$( numfmt --from=auto ${y_fieldcount:-10} )
    local y_fieldlength=$( numfmt --from=auto ${y_fieldlength:-5} )
    local chunk_insertstart=$( numfmt --from=auto ${chunk_insertstart:-0} )
    local chunk_recordcount=$( numfmt --from=auto ${chunk_recordcount:-10} )

    rm -rf $datafile >/dev/null 2>&1
    #mkfifo ${datafile}
    # hardcoded data dense generator
    # seq 0 10000 | \
    #    awk '{printf "%10d,%0100d,%0100d,%0100d,%0100d,%0100d,%0100d,%0100d,%0100d,%0100d,%0100d\n", \
    #        $1,$1,$1,$1,$1,$1,$1,$1,$1,$1,$1}' > ${datafile}

    # 1 <= y_fillstart <= fillend <= fieldcount 
    if (( y_fillend > y_fieldcount )); then y_fillend=$y_fieldcount; fi
    if (( y_fillstart > y_fillend )); then y_fillend=$y_fieldcount; fi

    # generate data
    seq ${chunk_insertstart} $(( ${chunk_recordcount} - 1 )) | \
    awk "{printf \"%d\",\$1; 
      # prefix nulls if any
      for (i=1;i<${y_fillstart};i++) printf \",\";
      # data
      for (;i<=${y_fillend};i++) printf \",%0${y_fieldlength}d\",\$1;
      # trailing nulls if any
      for (;i<=${y_fieldcount};i++) printf \",\";
      printf \"\n\"}" > ${datafile}
}


# wait for db to be up
ping_sql_cli() {
  local -i max_wait=${1:-10}
  local -i count=0
  local -i rc=1
  while (( (rc != 0) && (count < max_wait) )); do
    echo "select 1;" | sql_root_cli > /dev/null
    rc=${PIPESTATUS[1]}
    if (( rc == 0 )); then 
      break
    else
      count=$(( count + 1 ))
      echo "$count: waiting for db"
      sleep 1
    fi 
  done
  return $rc
}

jdbc_root_cli() {
  if [ -z "$(command -v jsqsh)" ]; then export PATH=/opt/stage/bin/jsqsh-dist-3.0-SNAPSHOT/bin$:$PATH; fi
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
  if [ -z "$(command -v jsqsh)" ]; then export PATH=/opt/stage/bin/jsqsh-dist-3.0-SNAPSHOT/bin$:$PATH; fi
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
    export SRCDB_GRP=postgresql
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

    # database dependent 
    local port=${1:-5432}

    # jdbc params for ycsb and jsqsh
    if [ -n "$(netstat -an | grep -i listen | grep ${port})" ]; then
      export SRCDB_PORT=${port}
    elif [ -n "$(command -v podman)" ]; then
      export SRCDB_PORT=$(podman port --all | grep "${port}/tcp" | head -n 1 | cut -d ":" -f 2)
    fi
    
    if [ -z "$SRCDB_PORT" ]; then
      echo "Error: database is not running." >&2; return 1
    fi

    set_jdbc_vars

    if [ ! -x jsqsh ]; then
      export PATH=/opt/stage/bin/jsqsh-dist-3.0-SNAPSHOT/bin:$PATH
      echo "PATH=/opt/stage/bin/jsqsh-dist-3.0-SNAPSHOT/bin added"
    fi

    set_ycsb_classpath

  # setup logdir
  export LOG_DIR=/var/tmp/${SRCDB_ARC_USER}/${SRCDB_GRP}/logs
  export CFG_DIR=/var/tmp/${SRCDB_ARC_USER}/${SRCDB_GRP}/config
  export YCSB_LOG_DIR=${LOG_DIR}/ycsb
  if [ ! -d ${LOG_DIR} ]; then mkdir -p ${LOG_DIR}; fi
  if [ ! -d ${CFG_DIR} ]; then mkdir -p ${CFG_DIR}; fi
  if [ ! -d ${YCSB_LOG_DIR} ]; then mkdir -p ${YCSB_LOG_DIR}; fi    
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
  heredoc_file demo/${SRCDB_GRP}/sql/ycsb.sql | tee -a $CFG_DIR/ycsb.sql | sql_cli
}

dump_schema() {
  local TABLE_NAME
  if [ -n "${1}" ]; then 
    TABLE_NAME="table_name = '${1}' and"
  fi

  sql_cli <<EOF > $CFG_DIR/schema_dump.csv
select table_name,column_name,data_type, column_default, is_nullable, character_maximum_length, numeric_precision, numeric_scale, datetime_precision 
from information_schema.columns 
WHERE ${TABLE_NAME} table_schema='${SRCDB_SCHEMA}' and table_catalog='${SRCDB_DB}' 
order by table_catalog, table_schema, table_name,ordinal_position;
EOF
  echo "schema dump at $CFG_DIR/schema_dump.csv" >&2
}

list_tables() {
  sql_cli <<EOF
SELECT table_name, table_type FROM information_schema.tables where table_type in ('BASE TABLE','VIEW') and table_schema like '${SRCDB_SCHEMA:-%}' and table_catalog like '${SRCDB_ARC_USER:-%}' order by table_name
go
EOF
}

list_table_counts() {
  rm $CFG_DIR/list_table_counts.sql 2>/dev/null
  for tables in $(list_regular_tables | grep -v "^replicate" ); do
    echo "select '$tables', min(a.ycsb_key), max(a.ycsb_key), max(b.field_count) from $tables a, (select max(ordinal_position)-1 field_count from information_schema.columns where table_name='$tables' and table_schema='${SRCDB_SCHEMA}' and table_catalog='${SRCDB_DB}') b;" >> $CFG_DIR/list_table_counts.sql  
  done
  if [ -f $CFG_DIR/list_table_counts.sql ]; then 
    cat $CFG_DIR/list_table_counts.sql | sql_cli > $CFG_DIR/list_table_counts.csv
  else
    touch $CFG_DIR/list_table_counts.sql
  fi
  echo "table count at $CFG_DIR/list_table_counts.csv" >&2
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

drop_all_ycsb_tables() {
  list_tables | awk -F ',' '/^YCSB/ {printf "drop table %s;\n",$1}' | sql_cli
  rm $CFG_DIR/list_table_counts.csv 2>/dev/null
  rm $CFG_DIR/schema_dump.csv 2>/dev/null
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
  sql_cli <<EOF
select count(*) from ${fq_table_name};
EOF
}

load_ycsb() {
  # check required param
  create_ycsb_table
  # set default params
  local y_tablename="-p table=${fq_table_name}"
  # run
  pushd /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/ >/dev/null
  #JAVA_HOME=$( find /usr/lib/jvm/java-8-openjdk-* -maxdepth 0 ) \
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
  local tabletype

  echo "running ycsb on $CFG_DIR/list_table_counts.csv"
  pushd /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/ >/dev/null
  for tablestat in $(cat $CFG_DIR/list_table_counts.csv); do
    [ -n "$YCSB_DEBUG" ] && echo -n "$tablestat"

    # read from the stat
    local table_name
    local record_start
    local record_end
    local record_count
    local field_count
    convert_table_stat_to_var "${tablestat}"

    if [[ "${table_name,,}" =~ "dense" ]]; then tabletype="dense"; else tabletype="sparse";fi
    if [ -z "${record_count}" ] || [ "${record_count}" = "[NULL]" ]; then echo "record_count not defined.  run list_table_counts or load data"; return 1; fi
    if [ -z "${field_count}"  ] || [ "${field_count}"  = "[NULL]" ]; then echo "field_count not defined.  run list_table_counts"; return 1; fi

    # ycsb parameter name of insert is actually update  
    local deletestart=$record_start
    # the / 1 trucates the float to int in bc
    # note y_del_proportion 100 x the records are mark for delete.
    local deletecount=$( bc <<< "$record_count * ${y_del_proportion:-0} * 100 / 1" )
    local updatestart=$(( record_start + deletecount ))
    local updatecount=$(( record_count - deletecount ))
    local insertstart=$(( record_end + 1 )) 

    # read from the env vars
    local _y_threads=$(var_name "threads" "$tabletype")
    local _y_target=$(var_name "target" "$tabletype")
    local _y_fieldlength=$(var_name "fieldlength" "$tabletype")
    local _y_multiupdatesize=$(var_name "multiupdatesize" "$tabletype")
    local _y_multideletesize=$(var_name "multideletesize" "$tabletype")
    local _y_multiinsertsize=$(var_name "multiinsertsize" "$tabletype")

    [ -n "$YCSB_DEBUG" ] && echo "table_name=$table_name tabletype=$tabletype record_count=$record_count field_count=$field_count _y_threads=${!_y_threads} _y_target=${!_y_target} _y_fieldlength=${!_y_fieldlength}"

    # run
    # JAVA_HOME=$( find /usr/lib/jvm/java-8-openjdk-* -maxdepth 0 ) \
    bin/ycsb.sh run jdbc -s -P workloads/workloada -p table=${table_name} \
    -p db.driver=$SRCDB_JDBC_DRIVER \
    -p db.url=$SRCDB_JDBC_URL \
    -p db.user="$SRCDB_ARC_USER" \
    -p db.passwd="$SRCDB_ARC_PW" \
    -p db.urlsharddelim='___' \
    -p jdbc.autocommit=true \
    -p jdbc.fetchsize=10 \
    -p db.batchsize=1000 \
    -p operationcount=10000000 \
    -p jdbc.ycsbkeyprefix=false \
    -p insertorder=ordered \
    -p readproportion=0 \
    -p deleteproportion=${y_del_proportion:-0} \
    -p deletestart=${deletestart} \
    -p deletecount=${deletecount} \
    -p updateproportion=${y_upd_proportion:-1} \
    -p insertstart=${updatestart} \
    -p insertcount=${updatecount} \
    -p insertproportion=${y_ins_proportion:-0} \
    -p recordcount=${insertstart} \
    -p fieldcount=${field_count:-10} \
    -p fieldlength=${y_fieldlength:-100} \
    -p jdbc.prependtimestamp=true \
    -p jdbc.multiupdatesize=${!_y_multiupdatesize:-1} \
    -p jdbc.multideletesize=${!_y_multideletesize:-1} \
    -p jdbc.multiinsertsize=${!_y_multiinsertsize:-1} \
    -threads ${!_y_threads:-1} \
    -target ${!_y_target:-1} "${@}" >$YCSB_LOG_DIR/ycsb.$table_name.log 2>&1 &
    
    done

    popd >/dev/null


    echo "ycsb can be killed with . ./demo/sqlserver/run-ycsb-sqlserver-source.sh; kill_ycsb)"

    # setup tmux
    send_command_tmux_window "$DBX_USERNAME" "ycsb" "cd ${YCSB_LOG_DIR}; tail -f ycsb.*.log"
    tmux select-window -t "$DBX_USERNAME":ycsb
  }


# wait for the log file to exist before running tail
wait_log() {
  LOGFILE=$1
  LOG_WAIT_SEC=1
  # -f is file exists
  # -s is empty
  while [ ! -f "${LOGFILE}" ] && [ ! -s "${LOGFILE}" ]; do 
    sleep ${LOG_WAIT_SEC}
    echo "waiting for ${LOGFILE}"
  done
}

set_arcion_java_home() {
  if [ "$(java -version 2>&1 | head -n 1 | awk '{print $NF}' | sed s/\"// | awk -F. '{printf "%s.%s",$1,$2}')" != "1.8" ]; then  
    echo "default java is not 1.8."
    export ARCION_JAVA_HOME=$( find /usr/lib/jvm/java-8-openjdk-* -maxdepth 0 )
    echo "setting ARCION_JAVA_HOME to $ARCION_JAVA_HOME"
  fi
  echo $ARCION_JAVA_HOME
}

arcion_version_from_url() {
  # remove leading names and trailing .zip
  export ARCION_DOWNLOAD_URL=${ARCION_DOWNLOAD_URL:-https://arcion-releases.s3.us-west-1.amazonaws.com/general/replicant/replicant-cli-24.01.25.7.zip}
  export ARCION_DIRNAME=$( basename $ARCION_DOWNLOAD_URL .zip  )
  export ARCION_HOME="${ARCION_BASEDIR}/${ARCION_DIRNAME}"
  export ARCION_BIN="$( find ${ARCION_HOME} -maxdepth 4 -name replicate -o -name replicant )" 
}

# set JAVA_HOME ARCION_HOME ARCION_BIN
replicant_or_replicate() {
  if [ -z "${ARCION_DOWNLOAD_URL}" ]; then
    # pick the latest from downloaded
    export ARCION_BIN=${ARCION_HOME:-$( find ${ARCION_BASEDIR} -maxdepth 4 -name replicate -o -name replicant | sort -r --version-sort | head -n 1)}
  else
    # use the specified
    arcion_version_from_url
  fi

  if [[ ( -z "$ARCION_BIN" ) || ( ! -x "$ARCION_BIN" ) ]]; then   
    echo "$ARCION_BASEDIR does not have replicant or replicate" >&2
    return 1
  fi
}

run_arcion() {
  JAVA_HOME="$ARCION_JAVA_HOME" \
  $ARCION_BIN "$@"
}

# set ARCION_VERSION
arcion_version() {
  if ! replicant_or_replicate; then
    echo "arcion not found." 
    return 1
  fi
  export ARCION_VERSION="$(run_arcion version 2>/dev/null | grep Version | awk -F' ' '{print $NF}')"
  export ARCION_YYMM=$(echo $ARCION_VERSION | awk -F'.' '{print $1 "." $2}')
  echo "$ARCION_BIN $ARCION_VERSION $ARCION_YYMM"
}

# --clean-job
# a_repltype:-"real-time"
# a_yamldir:-"./yaml/change"
start_arcion() {
  if [[ ( -z "$ARCION_BIN" ) || ( ! -x "$ARCION_BIN" ) ]]; then
    replicant_or_replicate
  fi

  local a_repltype="${a_repltype:-"real-time"}"   # snapshot real-time full
  local a_root_yamldir="${a_root_yamldir:-"./yaml"}"
  local a_yamldir="${a_yamldir:-"./yaml/change"}"

  # check license 
  if [ ! -f "/opt/stage/arcion/replicant.lic" ]; then
    echo "/opt/stage/arcion/replicant.lic not found."
    return 1
  fi

  # check access token
  if [[ ( -z "${DBX_ACCESS_TOKEN}" ) && ( "${DSTDB_TYPE,,}" != "null" ) ]]; then
    echo "personal access token not entered."
    return 1
  fi

  # check dst config 
  if [ ! -d "${a_yamldir}" ]; then echo "$a_yamldir should be a dir." >&2; return 1; fi
  if [ ! -f ${a_yamldir}/dst_${DSTDB_TYPE}.yaml ]; then echo " ${a_yamldir}/dst_${DSTDB_TYPE}.yaml" >&2; return 1; fi
  if [ ! -f ${a_yamldir}/applier_${DSTDB_TYPE}.yaml ]; then echo "${a_yamldir}/applier_${DSTDB_TYPE}.yaml not found." >&2; return 1; fi

  # cfg dir has log dir using nine_char_id 
  local NINE_CHAR_ID=${NINE_CHAR_ID:-$(nine_char_id)}
  local ARCION_CFG_DIR=$LOG_DIR/$NINE_CHAR_ID
  local ARCION_LOG_DIR=$ARCION_CFG_DIR            # cfg is the same as the LOG_DIR 
  local ARCION_NULL_DIR=$ARCION_LOG_DIR/null      # arcion creates ./*
  local ARCION_META_DIR=$ARCION_CFG_DIR/metadata  # arcion creates ./NINE_CHAR_ID/NINE_CHAR_ID 
  local ARCION_STATS_DIR=$LOG_DIR                 # arcion creates ./NINE_CHAR_ID/replication_statistics_history_*.CSV
  mkdir -p $ARCION_LOG_DIR
  mkdir -p $ARCION_CFG_DIR
  mkdir -p $ARCION_META_DIR
  mkdir -p $ARCION_NULL_DIR
  mkdir -p $ARCION_STATS_DIR

  local DBX_DBFS_ROOT=$(echo $DBX_DBFS_ROOT | tr '.@' '_')
  local DBX_USERNAME=$(echo $DBX_USERNAME | tr '.@' '_')

  # prepare the YAML file
  heredoc_file ${a_yamldir}/src.yaml                    >${ARCION_CFG_DIR}/src.yaml      
  heredoc_file ${a_yamldir}/dst_${DSTDB_TYPE}.yaml      >${ARCION_CFG_DIR}/dst.yaml      
  heredoc_file ${a_yamldir}/applier_${DSTDB_TYPE}.yaml  >${ARCION_CFG_DIR}/applier.yaml   
  heredoc_file ${a_yamldir}/general.yaml                >${ARCION_CFG_DIR}/general.yaml 
  heredoc_file ${a_yamldir}/extractor.yaml              >${ARCION_CFG_DIR}/extractor.yaml 
  heredoc_file ${a_yamldir}/filter.yaml                 >${ARCION_CFG_DIR}/filter.yaml  
  heredoc_file ${a_root_yamldir}/statistics.yaml        >${ARCION_CFG_DIR}/statistics.yaml  
  if [ -f ${a_yamldir}/map_${DSTDB_TYPE}.yaml ]; then heredoc_file ${a_yamldir}/map_${DSTDB_TYPE}.yaml > ${ARCION_CFG_DIR}/map.yaml; fi

  # write mode
  local WRITE_MODE="--replace"
  if [[ "${a_repltype}" = "real-time" ]]; then local WRITE_MODE="--append-existing"; fi

  # mapper
  local MAPPER=""
  if [ -f "${ARCION_CFG_DIR}/map.yaml" ]; then MAPPER="--map ${ARCION_CFG_DIR}/map.yaml"; fi

  # metadata
  local METADATA=""
  #if [[ "${DSTDB_TYPE,,}" = 'null' ]]; then 
      heredoc_file ${a_yamldir}/metadata.yaml >${ARCION_CFG_DIR}/metadata.yaml  
      METADATA="--metadata ${ARCION_CFG_DIR}/metadata.yaml"; 
  #fi

  # run arcion
  set -x 
  cd $ARCION_CFG_DIR; JAVA_HOME="$ARCION_JAVA_HOME" \
  REPLICANT_MEMORY_PERCENTAGE=${REPLICANT_MEMORY_PERCENTAGE:-10.0} \
  JAVA_OPTS='"-Djava.security.egd=file:/dev/urandom" "-Doracle.jdbc.javaNetNio=false" "-XX:-UseCompressedOops"' \
  $ARCION_BIN    "${a_repltype}" \
                 ${ARCION_CFG_DIR}/src.yaml \
                 ${ARCION_CFG_DIR}/dst.yaml \
    --applier    ${ARCION_CFG_DIR}/applier.yaml \
    --general    ${ARCION_CFG_DIR}/general.yaml \
    --extractor  ${ARCION_CFG_DIR}/extractor.yaml \
    --filter     ${ARCION_CFG_DIR}/filter.yaml \
    --statistics ${ARCION_CFG_DIR}/statistics.yaml \
    $MAPPER $METADATA\
    --overwrite --id $NINE_CHAR_ID $WRITE_MODE >${ARCION_CFG_DIR}/arcion.log 2>&1 &
    set +x

  ARCION_PID=$!
  echo $ARCION_PID > $ARCION_CFG_DIR/arcion.pid
  echo "arcion pid $ARCION_PID"  
  echo "arcion console is at $ARCION_CFG_DIR/arcion.log"
  echo "arcion log is at $ARCION_CFG_DIR"
  echo "arcion can be killed with . ./demo/sqlserver/run-ycsb-sqlserver-source.sh; kill_arcion)"

  # setup tmux
  send_command_tmux_window "$DBX_USERNAME" "console" "cd ${ARCION_LOG_DIR}; while [ ! -f arcion.log ]; do sleep 1; echo sleep 1; done; tail -f arcion.log"
  send_command_tmux_window "$DBX_USERNAME" "trace" "cd ${ARCION_LOG_DIR}; while [ ! -f ${NINE_CHAR_ID}/trace.log ]; do sleep 1; echo sleep 1; done; tail -f ${NINE_CHAR_ID}/trace.log"
  send_command_tmux_window "$DBX_USERNAME" "error" "cd ${ARCION_LOG_DIR}; while [ ! -f ${NINE_CHAR_ID}/error_trace.log ]; do sleep 1; echo sleep 1; done; tail -f ${NINE_CHAR_ID}/error_trace.log"
  send_command_tmux_window "$DBX_USERNAME" "logdir" "cd ${ARCION_LOG_DIR}"
  tmux select-window -t "$DBX_USERNAME":console
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
  for pid in $(ps -eo pid,command | grep -e '/bin/sh .*/ycsb.sh' | grep -v grep | awk '{print $1}'); do 
    kill_recurse "$pid"
  done 
}

kill_arcion() { 
  # space in the front sh is important
  for pid in $(ps -eo pid,command | grep -e '\bsh .*replicant' -e '\bsh .*replicate' | grep -v grep | awk '{print $1}'); do    
    kill_recurse "$pid"
  done 
}


show_arcion_error() {
  ARCION_PID=$(cat $LOG_DIR/arcion.pid)
  wait_log /opt/stage/demo/oraclerac/logs/$ARCION_PID/error_trace.log
  tail -f /opt/stage/demo/oraclerac/logs/$ARCION_PID/error_trace.log
}

show_arcion_trace() {
  ARCION_PID=$(cat $LOG_DIR/arcion.pid)
  wait_log /opt/stage/demo/oraclerac/logs/$ARCION_PID/trace.log
  tail -f /opt/stage/demo/oraclerac/logs/$ARCION_PID/trace.log
}


# Parameters
#   YCSB_TARGET=${1:-0}
#   SVC_NAME=${2:-cdb_svc}
restart_ycsb() {
  while [ 1 ]; do
      wait_log ${YCSB_LOG_DIR}/ycsb.run.tps1.$$
      tail -f ${YCSB_LOG_DIR}/ycsb.run.tps1.$$ | awk '/^Error in processing update to table: usertablejava.sql.SQLException: Closed Statement/ {print "Error"; exit 1} {print $0}'
      RC=${PIPESTATUS[1]}
      if [ "$RC" != 0 ]; then 
          echo "needs restart"; 
          set -x
          kill $(cat $LOG_DIR/ycsb.$$.pid)
          while [ -n "$(ps --no-headers $(cat $LOG_DIR/ycsb.$$.pid))" ]; do
            kill $(cat $LOG_DIR/ycsb.$$.pid)
            sleep 1
            echo "waiting clean up of $(cat $LOG_DIR/ycsb.$$.pid)" 
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

cat <<EOF | jdbc_root_cli "$@"

-- show catalog
select name, suser_sname(owner_sid) "owner_name", is_cdc_enabled, is_change_feed_enabled, is_published, is_encrypted from sys.databases
where name in ('${SRCDB_DB}')
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


port_db "$@"
