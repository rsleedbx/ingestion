#!/usr/bin/env bash

export CLASSPATH=$(find /opt/stage/libs -name "*.jar" ! -name "log" | paste -s -d":")    
export PATH=/opt/stage/bin/jsqsh-dist-3.0-SNAPSHOT/bin:$PATH
jsqsh cdbrac <<EOF
-- 
CREATE USER c##arcsrc IDENTIFIED BY Passw0rd CONTAINER=ALL;
GRANT CREATE SESSION TO c##arcsrc CONTAINER=ALL;
grant connect,resource to c##arcsrc container=all;


-- not sure if required
-- grant select any dictionary to c##arcsrc container=all;
-- grant all on DBMS_LOGMNR_D to c##arcsrc container=all;

ALTER USER c##arcsrc default tablespace USERS;

ALTER USER c##arcsrc quota unlimited on USERS;
-- 

grant execute_catalog_role to c##arcsrc;

grant select_catalog_role to c##arcsrc;

--
grant dba to c##arcsrc contailer=all;

--
ALTER DATABASE FORCE LOGGING;

ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- II. Set up Oracle User

CREATE USER C##ARCSRC IDENTIFIED BY Passw0rd  CONTAINER=ALL;

GRANT CREATE SESSION TO C##ARCSRC CONTAINER=ALL;

ALTER USER C##ARCSRC default tablespace USERS;

ALTER USER C##ARCSRC quota unlimited on USERS;

GRANT
    SELECT ANY TABLE,
    INSERT ANY TABLE,
    UPDATE ANY TABLE,
    DELETE ANY TABLE,
    CREATE ANY TABLE,
    ALTER ANY TABLE,
    DROP ANY TABLE
    TO C##ARCSRC;

GRANT
    CREATE ANY SEQUENCE,
    SELECT ANY SEQUENCE,
    CREATE ANY INDEX
    TO C##ARCSRC;

GRANT SET CONTAINER TO  C##ARCSRC CONTAINER=ALL;

GRANT SELECT ON DBA_PDBS to C##ARCSRC CONTAINER=ALL;

-- required even non CDC
GRANT SELECT ON gv_\$instance TO C##ARCSRC;

-- 3 CDC

GRANT EXECUTE_CATALOG_ROLE TO C##ARCSRC;
GRANT LOGMINING TO C##ARCSRC;


GRANT SELECT ON v_\$logmnr_contents TO C##ARCSRC;
GRANT SELECT ON gv_\$archived_log TO C##ARCSRC;
GRANT SELECT ON gv_\$logfile TO C##ARCSRC;
-- below Oracle 19c
GRANT SELECT ON v_\$logfile TO C##ARCSRC;

-- Enable logs on database
-- https://docs.arcion.io/docs/source-setup/oracle/setup-guide/oracle-traditional-database/#enable-logs
-- not having this will result in
-- CDC not enabled
ALTER DATABASE FORCE LOGGING;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
--

GRANT CREATE SESSION TO C##ARCSRC;
GRANT SELECT ANY TABLE TO C##ARCSRC;

GRANT SELECT ON gv_\$instance TO C##ARCSRC;
GRANT SELECT ON gv_\$PDBS TO C##ARCSRC;
GRANT SELECT ON gv_\$log TO C##ARCSRC;
GRANT SELECT ON gv_\$database_incarnation to C##ARCSRC;

-- 4 setup global permissions
-- https://docs.arcion.io/docs/source-setup/oracle/setup-guide/oracle-traditional-database/#iv-set-up-global-permissions

-- onetime
GRANT SELECT ON DBA_SEGMENTS TO C##ARCSRC;

-- snapshot and CDC
GRANT SELECT ON gv_\$database TO C##ARCSRC;
GRANT SELECT ON gv_\$transaction TO C##ARCSRC;
--Not required for replicant release 20.8.13.7 and above
GRANT SELECT ON gv_\$session TO C##ARCSRC;

-- CDC
GRANT FLASHBACK ANY TABLE TO C##ARCSRC;

-- schema migration
GRANT SELECT ON ALL_TABLES TO C##ARCSRC;
GRANT SELECT ON ALL_VIEWS TO C##ARCSRC;
GRANT SELECT ON ALL_CONSTRAINTS TO C##ARCSRC;
GRANT SELECT ON ALL_CONS_COLUMNS TO C##ARCSRC;
GRANT SELECT ON ALL_PART_TABLES TO C##ARCSRC;
GRANT SELECT ON ALL_PART_KEY_COLUMNS TO C##ARCSRC;
GRANT SELECT ON ALL_TAB_COLUMNS TO C##ARCSRC;
GRANT SELECT ON SYS.ALL_INDEXES TO C##ARCSRC;
GRANT SELECT ON SYS.ALL_IND_COLUMNS TO C##ARCSRC;
GRANT SELECT ON SYS.ALL_IND_EXPRESSIONS TO C##ARCSRC;

-- native log reader
GRANT SELECT ON gv_\$instance TO C##ARCSRC;
GRANT SELECT ON v_\$log TO C##ARCSRC;
GRANT SELECT ON v_\$logfile TO C##ARCSRC;
GRANT SELECT ON v_\$archived_log to C##ARCSRC;
GRANT SELECT ON dba_objects TO C##ARCSRC;
GRANT SELECT ON v_\$transportable_platform TO C##ARCSRC;

-- missing in the docs
-- native log reader
GRANT SELECT ON V_$DATABSSE TO C##ARCSRC;

-- missing in the docs
-- GIANT HACK as there are others missing as well
 grant dba to  C##ARCSRC;

GRANT CREATE SESSION TO C##ARCSRC;
GRANT EXECUTE_CATALOG_ROLE TO C##ARCSRC;
GRANT SELECT ANY TABLE TO C##ARCSRC;
GRANT SELECT ON all_constraints TO C##ARCSRC;
GRANT SELECT ON all_cons_columns TO C##ARCSRC;
GRANT SELECT ON all_indexes TO C##ARCSRC;
GRANT SELECT ON all_ind_expressions TO C##ARCSRC;
GRANT SELECT ON all_part_tables TO C##ARCSRC;
GRANT SELECT ON all_part_key_columns TO C##ARCSRC;
GRANT SELECT ON all_tables TO C##ARCSRC;
GRANT SELECT ON all_tab_columns TO C##ARCSRC;
GRANT SELECT ON all_views TO C##ARCSRC;
GRANT SELECT ON dba_constraints TO C##ARCSRC;
GRANT SELECT ON dba_cons_columns TO C##ARCSRC;
GRANT SELECT ON dba_indexes TO C##ARCSRC;
GRANT SELECT ON dba_ind_columns TO C##ARCSRC;
GRANT SELECT ON dba_lobs TO C##ARCSRC;
GRANT SELECT ON dba_objects TO C##ARCSRC;
GRANT SELECT ON dba_roles TO C##ARCSRC;
GRANT SELECT ON dba_tables TO C##ARCSRC;
GRANT SELECT ON dba_tab_cols TO C##ARCSRC;
GRANT SELECT ON gv_\$database TO C##ARCSRC;
GRANT SELECT ON gv_\$instance TO C##ARCSRC;
GRANT SELECT ON gv_\$transaction TO C##ARCSRC;
GRANT SELECT ON v_\$archived_log to C##ARCSRC;
GRANT SELECT ON v_\$database TO C##ARCSRC;
GRANT SELECT ON v_\$log TO C##ARCSRC;
GRANT SELECT ON v_\$logfile TO C##ARCSRC;
GRANT SELECT ON v_\$transportable_platform TO C##ARCSRC;

-- for exp / imp
-- 
--grant read,write on directory SHARED_STAGE to C##ARCSRC;


EOF


jsqsh -n arcsrc <<EOF
CREATE TABLE usertable (
    YCSB_KEY NUMBER PRIMARY KEY,
    FIELD0 VARCHAR2(255), FIELD1 VARCHAR2(255),
    FIELD2 VARCHAR2(255), FIELD3 VARCHAR2(255),
    FIELD4 VARCHAR2(255), FIELD5 VARCHAR2(255),
    FIELD6 VARCHAR2(255), FIELD7 VARCHAR2(255),
    FIELD8 VARCHAR2(255), FIELD9 VARCHAR2(255)
) organization index; 
EOF

jsqsh -n arcsrcpdb1 <<EOF
CREATE TABLE usertable (
    YCSB_KEY NUMBER PRIMARY KEY,
    FIELD0 VARCHAR2(255), FIELD1 VARCHAR2(255),
    FIELD2 VARCHAR2(255), FIELD3 VARCHAR2(255),
    FIELD4 VARCHAR2(255), FIELD5 VARCHAR2(255),
    FIELD6 VARCHAR2(255), FIELD7 VARCHAR2(255),
    FIELD8 VARCHAR2(255), FIELD9 VARCHAR2(255)
) organization index; 
EOF


ssh-copy-id oracle@ol7-19-rac1
ssh-copy-id oracle@ol7-19-rac2

# show database
ssh oracle@ol7-19-rac1 ". ~/.bash_profile; srvctl status database -d cdbrac"
# show service
ssh oracle@ol7-19-rac1 ". ~/.bash_profile; srvctl status service -db cdbrac"


# setup cdb

srvctl add service -db cdbrac -service cdb_svc -preferred cdbrac1 -available cdbrac2 -failovermethod BASIC -failovertype SELECT -failoverretry 180 -failoverdelay 5
srvctl start service -db cdbrac -service cdb_svc -instance cdbrac1
srvctl relocate service -db cdbrac -service cdb_svc -oldinst cdbrac1 -newinst cdbrac2 -stopoption immediate -f
srvctl relocate service -db cdbrac -service cdb_svc -oldinst cdbrac2 -newinst cdbrac1 -stopoption immediate -f

# setup pdb
srvctl remove service -db cdbrac -service pdb1_svc -force
srvctl add service -db cdbrac -service pdb1_svc -pdb pdb1 -preferred cdbrac1 -available cdbrac2 
#
srvctl start service -db cdbrac -service pdb1_svc
srvctl start service -db cdbrac -service pdb1_svc -instance cdbrac1

# status
srvctl status service -db cdbrac

# -failovermethod BASIC -failovertype SELECT -failoverretry 180 -failoverdelay 5
