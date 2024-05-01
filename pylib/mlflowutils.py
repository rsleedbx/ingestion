
# use process to run MLflow without blocking the notebook.  thread does not work with mlflow

import mlflow
import time
import os
import numpy as np
from multiprocessing import Process
from file_read_backwards import FileReadBackwards
import glob

def log_artifacts():
    pass

from file_read_backwards import FileReadBackwards
import datetime

# convert ycsb log mlflow metric
# time                    elapsed  cumulative      time period                                   per operations metric
#                         sec      operations      ops/sec
# 2024-03-07 10:05:38:240 410 sec: 409 operations; 1 current ops/sec; est completion in 116 days [UPDATE: Count=10, Max=15383, Min=6792, Avg=9264.6, 90=15359, 99=15383, 99.9=15383, 99.99=15383]
# ycsb_tablename_[update|update-failed]_count=x
# ycsb_tablename_[update|update-failed]_avg_microsec=x 

ycsb_date_time_pattern = r"^(?P<dt>[0-9\-]+ [0-9\:]+)"  # at the beginning
ycsb_op_val_pattern = r'\[([^]]*)\]'                    # [Update: ] [Insert: ] ...



def tablulate_arc_stat_line(count, stat_type, cat_sch_tbl, arc_stats, replicant_lag, total_lag, replicant_lag_weights, total_lag_weights):
    if count > 0:
        #  per table DML stat
        # catalog_schema_tablename
        try:
            arc_stats[f"arcion/{stat_type}_{cat_sch_tbl}"] += count
        except:
            arc_stats[f"arcion/{stat_type}_{cat_sch_tbl}"] = count
        # overall DML 
        try:
            arc_stats[f"arcion/{stat_type}"] += count
        except:
            arc_stats[f"arcion/{stat_type}"] = count

        # skip defaut_lag value of 9223372036854775807   
        if replicant_lag != arc_default_lag:
            try:
                replicant_lag_weights[f"arcion/{stat_type}_{cat_sch_tbl}"] += count * replicant_lag
            except:
                replicant_lag_weights[f"arcion/{stat_type}_{cat_sch_tbl}"] = count * replicant_lag
            # overall DML 
            try:
                replicant_lag_weights[f"arcion/{stat_type}"] += count * replicant_lag
            except:
                replicant_lag_weights[f"arcion/{stat_type}"] = count * replicant_lag

        # skip defaut_lag value of 9223372036854775807   
        if total_lag != arc_default_lag:
            try:
                total_lag_weights[f"arcion/{stat_type}_{cat_sch_tbl}"] += count * total_lag
            except:
                total_lag_weights[f"arcion/{stat_type}_{cat_sch_tbl}"] = count * total_lag
            # overall DML 
            try:
                total_lag_weights[f"arcion/{stat_type}"] += count * total_lag
            except:
                total_lag_weights[f"arcion/{stat_type}"] = count * total_lag

        # per table weighted avg = weight / count
        # could be case where replicant_lag_weight is not known 9223372036854775807
        if f"arcion/{stat_type}_{cat_sch_tbl}" in replicant_lag_weights:
            arc_stats[f"arcion/{stat_type}_lag_replicant_{cat_sch_tbl}"] = \
                replicant_lag_weights[f"arcion/{stat_type}_{cat_sch_tbl}"] / arc_stats[f"arcion/{stat_type}_{cat_sch_tbl}"]
            arc_stats[f"arcion/{stat_type}_lag_total_{cat_sch_tbl}"] = \
                total_lag_weights[f"arcion/{stat_type}_{cat_sch_tbl}"] / arc_stats[f"arcion/{stat_type}_{cat_sch_tbl}"]

        # overall DML 
        # could be case where replicant_lag_weight is not known 9223372036854775807            
        if f"arcion/{stat_type}" in total_lag_weights:
            arc_stats[f"arcion/{stat_type}_lag_replicant"] = \
                replicant_lag_weights[f"arcion/{stat_type}"] / arc_stats[f"arcion/{stat_type}"]
            arc_stats[f"arcion/{stat_type}_lag_total"] = \
                total_lag_weights[f"arcion/{stat_type}"] / arc_stats[f"arcion/{stat_type}"]

def set_previous_log(log_stat:dict, table_name:str=""):
    marker_key=f"marker_{table_name}"
    first_key=f"first_{table_name}"
    try:
        log_stat[marker_key] = log_stat[first_key]
    except:
        # marker could not not defined if the file was empty
        log_stat[marker_key] = None
    # clear the first line read
    log_stat[first_key] = None
    
def reached_previous_log(log_stat:dict, line:str, table_name:str="", header_line=None):
    marker_key=f"marker_{table_name}"
    first_key=f"first_{table_name}"    

    # reached header
    if header_line is None:
        pass
    elif line==header_line:
        return(True)

    # will be the highwater maker for the next run
    try:
        if log_stat[first_key] is None:
            log_stat[first_key] = line
    except:
        log_stat[first_key] = line
        
    # done when reached previous processed line
    try:
        if line==log_stat[marker_key]:
            return(True)
    except:
        # not previous marker
        pass

    return(False)

def parse_arcion_stats(run_id, user_id, db_type,arcion_stats_csv_positions):

    file_list = glob.glob(f"/var/tmp/{user_id}/{db_type}/logs/{run_id}/stats/{run_id}/{run_id}/replication_statistics_history_*.CSV")
    
    # file is not ready yet
    if len(file_list) == 0:
        return({})
    
    firstlineread = None
    arc_stats = {}
    # temp dict used for weighted average
    replicant_lag_weights = {}
    total_lag_weights = {}
    start_time=None
    end_time=None

    with FileReadBackwards(file_list[0], encoding="utf-8") as BigFile:
        for line in BigFile:
            if reached_previous_log(log_stat=arcion_stats_csv_positions, line=line, header_line=arcion_stats_csv_header_lines):
                break

            csvline=line.split(",")
            if (len(csvline)) < 13:
                continue

            if end_time is None:
                end_time = csvline[arc_stat_end_time_idx]
            start_time = csvline[arc_stat_start_time_idx]

            # arcion_key_index={'insert_count':7,'update_count':8,'upsert_count':9,'delete_count':10,'elapsed_time_sec':11,'replicant_lag':12,'total_lag':13}

            cat_sch_tbl=f"{csvline[arc_stat_catalog_name_idx]}_{csvline[arc_stat_schema_name_idx]}_{csvline[arc_stat_table_name_idx]}"
            try:
                insert_count=int(csvline[arc_stat_insert_count_idx])
            except:
                # could be header or some unknown format
                continue

            update_count=int(csvline[arc_stat_update_count_idx])
            upsert_count=int(csvline[arc_stat_upsert_count_idx])
            delete_count=int(csvline[arc_stat_delete_count_idx])
            replicant_lag=int(csvline[arc_stat_replicant_lag_idx])
            total_lag=int(csvline[arc_stat_total_lag_idx])

            tablulate_arc_stat_line(count=insert_count, stat_type="insert", cat_sch_tbl=cat_sch_tbl, arc_stats=arc_stats, replicant_lag=replicant_lag, total_lag=total_lag, replicant_lag_weights=replicant_lag_weights, total_lag_weights=total_lag_weights)
            tablulate_arc_stat_line(count=update_count, stat_type="update", cat_sch_tbl=cat_sch_tbl, arc_stats=arc_stats, replicant_lag=replicant_lag, total_lag=total_lag, replicant_lag_weights=replicant_lag_weights, total_lag_weights=total_lag_weights)
            tablulate_arc_stat_line(count=upsert_count, stat_type="upsert", cat_sch_tbl=cat_sch_tbl, arc_stats=arc_stats, replicant_lag=replicant_lag, total_lag=total_lag, replicant_lag_weights=replicant_lag_weights, total_lag_weights=total_lag_weights)
            tablulate_arc_stat_line(count=delete_count, stat_type="delete", cat_sch_tbl=cat_sch_tbl, arc_stats=arc_stats, replicant_lag=replicant_lag, total_lag=total_lag, replicant_lag_weights=replicant_lag_weights, total_lag_weights=total_lag_weights)


    # set the end marker
    set_previous_log(log_stat=arcion_stats_csv_positions)

    # calculate count / s metric 
    try:
        time_diff = (datetime.datetime.strptime(end_time, '%Y-%m-%dT%H:%M:%S.%fZ') -
            datetime.datetime.strptime(start_time, '%Y-%m-%dT%H:%M:%S.%fZ')).total_seconds()
    except:
        time_diff = 0

    for key in ["insert","update","upsert","delete"]:
        try:
            if time_diff > 1:
                arc_stats[f"arcion/{key}_s"] = arc_stats[f"arcion/{key}"] / time_diff
            else:
                arc_stats[f"arcion/{key}_s"] = arc_stats[f"arcion/{key}"]
        except:
            pass
        
    # return the stat
    return(arc_stats)


def tablulate_ycsb_stat_line(line,metrics,table_name):
    # parse [update: ...]
    m = re.findall(ycsb_op_val_pattern, line.lower())
    if m is None:
        return
    
    # [UPDATE: Count=891, Max=63423, Min=4, Avg=194.94, 90=210, 99=350, 99.9=715, 99.99=63423]
    for ops in m:
        op_vals=ops.split(":")                  # update: ....
        if len(op_vals) != 2:
            break

        vals_array=op_vals[1].split(",")        # count=?, max=?, ...
        if len(vals_array) != 8:
            break
        
        # count
        try:    
            op_count=float(vals_array[0].split("=")[1])    # [0] count=?
        except:
            op_count=0.0
        # per operation
        try:
            metrics[f"ycsb/{op_vals[0]}_{table_name}"] += op_count
        except:
            metrics[f"ycsb/{op_vals[0]}_{table_name}"] = op_count
        # overall
        try:
            metrics[f"ycsb/{op_vals[0]}"] += op_count
        except:
            metrics[f"ycsb/{op_vals[0]}"] = op_count

        # max
        try:
            op_max=float(vals_array[1].split("=")[1])      # [1] max=? if count=0, then this will be not defined
        except:
            op_max=0.0
        #pertable
        try:
            if metrics[f"ycsb/{op_vals[0]}_max_microsec_{table_name}"] < op_max:
                metrics[f"ycsb/{op_vals[0]}_max_microsec_{table_name}"] = op_max
        except:
            metrics[f"ycsb/{op_vals[0]}_max_microsec_{table_name}"] = op_max
        #overall
        try:
            if metrics[f"ycsb/{op_vals[0]}_max_microsec"] < op_max:
                metrics[f"ycsb/{op_vals[0]}_max_microsec"] = op_max
        except:
            metrics[f"ycsb/{op_vals[0]}_max_microsec"] = op_max


def parse_ycsb_log_to_metric(ycsb_logfile_positions,
                    start_time,
                    end_time,         
                    table_name="ycsbsparse",
                    file="/var/tmp/arcsrc/sqlserver/logs/ycsb/ycsb.ycsbsparse.log",
                    metrics={},
                    ):
    
    with FileReadBackwards(file, encoding="utf-8") as ycsb_log_file:
        count=0
        for line in ycsb_log_file:      
            if reached_previous_log(log_stat=ycsb_logfile_positions, line=line, table_name=table_name):
                break
            # endtime time
            if end_time is None:
                try:
                    # 2024-03-27 14:18:57:038
                    end_time = datetime.datetime.strptime(line[0:23], '%Y-%m-%d %H:%M:%S:%f')
                    print(f"end time from {table_name}:{end_time}")
                except:
                    pass
            
            # start time
            try:
                start_time = datetime.datetime.strptime(line[0:23], '%Y-%m-%d %H:%M:%S:%f')
                print(f"start time from {table_name}:{start_time}")
            except:
                pass
            tablulate_ycsb_stat_line(line=line,metrics=metrics,table_name=table_name)

    # set the end marker
    set_previous_log(log_stat=ycsb_logfile_positions, table_name=table_name)  
    return(start_time, end_time, metrics)            

def calc_count_s_ycsb(metrics, start_time, end_time):
    # calculate count / s metric       
    try:
        time_diff = (end_time - start_time).total_seconds()
    except:
        time_diff = 0

    print(start_time)
    print(end_time)
    print(time_diff)
    print(metrics.keys())
    for key in ["insert","update","delete"]:
        try:
            if time_diff > 1:
                metrics[f"ycsb/{key}_s"] = metrics[f"ycsb/{key}"] / time_diff
            else:
                metrics[f"ycsb/{key}_s"] = metrics[f"ycsb/{key}"]
        except:
            pass

def get_arcion_metrics(params:dict):
    arc_stats=parse_arcion_stats(
        run_id=params[arcion_run_id,
        user_id=params[src_username.value,
        db_type=params[src_db_type.value,
        arcion_stats_csv_positions=arcion_stats_csv_positions)
    return(arc_stats)

def get_ycsb_metrics(metrics={}):
    ycsb_current_metrics={}
    start_time=None
    end_time=None
    ycsb_tables = pd.read_csv (f"/var/tmp/{src_username.value}/sqlserver/config/list_table_counts.csv",header=None, names= ['table name','min key','max key','field count'])
    for table_name in ycsb_tables['table name']:
        table_name = table_name.lower()
        start_time, end_time, _ = parse_ycsb_log_to_metric(ycsb_logfile_positions,start_time, end_time,
            table_name=table_name, 
            file=f"/var/tmp/{src_username.value}/sqlserver/logs/ycsb/ycsb.{table_name}.log",
            metrics=ycsb_current_metrics,
            )
    calc_count_s_ycsb(ycsb_current_metrics, start_time, end_time)
    return(ycsb_current_metrics)

def get_prom_metrics(prom_metric_url=None,metric_prefix="",metric_step=None):
    # there is a limit on the number of metrics that you can log in a single log_batch call. This limit is typically 1000. 
    # timestamp=If unspecified, the number of milliseconds since the Unix epoch is used.
    # step=If unspecified, the default value of zero is used
    contents = requests.get(prom_metric_url)
    all_metrics = {}
    metrics_count = 0
    for line in contents.text.splitlines():
        if line.startswith("#"):
            continue
        key,val=line.rsplit(' ', 1)       # split from the end in case the key has spaces
        key=re.sub('[" {}=,]', "_", key)  # change space,{},=,and comma into _
        key=key.replace("_", "/", 1)      # change the first _ to / to group based on the name space
        all_metrics[key]=float(val)
        metrics_count += 1
    return(all_metrics)


def start_mlflow(max_intervals=0,experiment_id=None, log_interval_sec=10, all_params={}, step=0):
    # stop previous run
    # max_intervals=0 makes the mlflow run forever
    mlflow_run = mlflow.active_run()
    if not(mlflow_run is None):
        # upload final artifacts
        log_artifacts()
        print(f"""stopping previous MLflow {mlflow_run.info.run_id}""")
        mlflow.end_run()

    # start a new run
    if experiment_id == '':
        experiment_id=None
    mlflow.start_run(experiment_id=experiment_id, log_system_metrics=True)

    # params
    mlflow.log_params(params=all_params)

    # schema
    dataset_source=f"/var/tmp/{src_username.value}/sqlserver/config/list_table_counts.csv"
    mlflow.log_artifact(dataset_source)
    
    # data
    dataset_shape = pd.read_csv(dataset_source, header=None, names= ['table name','min key','max key','field count'])
    dataset = mlflow.data.from_pandas(dataset_shape, source=dataset_source)
    mlflow.log_input(dataset, context="training")    

    # wait to end
    # TODO: Make this smarter by checking whether the process is still running
    wait_count=0
    while (max_intervals == 0) or (wait_count < max_intervals):
        mlflow.log_metrics(metrics=get_prom_metrics(prom_metric_url="http://localhost:9399/metrics"),step=step)
        mlflow.log_metrics(metrics=get_prom_metrics(prom_metric_url="http://localhost:9100/metrics"),step=step)
        mlflow.log_metrics(metrics=get_ycsb_metrics(),step=step)
        mlflow.log_metrics(metrics=get_arcion_metrics(all_params=all_params),step=step)
        time.sleep(log_interval_sec)
        wait_count += 1
        step += 1

    # upload the rest of the artifacts generated /var/tmp/{src_username.value}/sqlserver/logs
    log_artifacts()
    # experiment done
    mlflow.end_run()

def register_mlflow(mlflow_proc_state, exp_params, experiment_id):
    mlflow_proc = Process(target=start_mlflow, kwargs={"experiment_id":experiment_id, "all_params":exp_params})
    mlflow_proc.start()   
    try:
        mlflow_proc_state['proc'].terminate()
        print("previous MLFlow process terminated")
    except:
        pass
    mlflow_proc_state['proc']       = mlflow_proc
    mlflow_proc_state['exp_params'] = exp_params

