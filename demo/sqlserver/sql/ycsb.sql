CREATE TABLE ${fq_table_name} (
	YCSB_KEY INT,
	FIELD0 TEXT, FIELD1 TEXT,
	FIELD2 TEXT, FIELD3 TEXT,
	FIELD4 TEXT, FIELD5 TEXT,
	FIELD6 TEXT, FIELD7 TEXT,
	FIELD8 TEXT, FIELD9 TEXT,
	PRIMARY KEY (YCSB_KEY),
)
go

-- required for DML CDC
ALTER TABLE  ${fq_table_name} ENABLE CHANGE_TRACKING;
go

-- required for DDL CDC
EXEC sys.sp_cdc_enable_table  
@source_schema = N'dbo',  
@source_name   = N'${fq_table_name}',  
@role_name     = NULL,  
@supports_net_changes = 0
go