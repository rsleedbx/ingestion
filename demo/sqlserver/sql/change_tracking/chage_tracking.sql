-- must be created in dbo
-- ACE-1932 can replicate_io_audit_ddl be located in schema other than dbo?

CREATE TABLE "replicate_io_audit_ddl"  (
"CURRENT_USER" NVARCHAR(128), 
"SCHEMA_NAME" NVARCHAR(128),
"TABLE_NAME" NVARCHAR(128),
"TYPE" NVARCHAR(30), 
"OPERATION_TYPE" NVARCHAR(30), 
"SQL_TXT" NVARCHAR(2000), 
"LOGICAL_POSITION" BIGINT, 
CONSTRAINT "replicate_io_audit_ddlPK" PRIMARY KEY("LOGICAL_POSITION")
);

ALTER TABLE "replicate_io_audit_ddl" ENABLE CHANGE_TRACKING;

CREATE TABLE "replicate_io_audit_tbl_schema"
(
"COLUMN_ID" BIGINT, 
"DATA_DEFAULT" BIGINT, 
"COLUMN_NAME" VARCHAR(128) NOT NULL, 
"TABLE_NAME" NVARCHAR(128) NOT NULL, 
"SCHEMA_NAME" NVARCHAR(128) NOT NULL, 
"HIDDEN_COLUMN" NVARCHAR(3), 
"DATA_TYPE" NVARCHAR(128), 
"DATA_LENGTH" BIGINT, 
"CHAR_LENGTH" BIGINT, 
"DATA_SCALE" BIGINT, 
"DATA_PRECISION" BIGINT, 
"IDENTITY_COLUMN" NVARCHAR(3), 
"VIRTUAL_COLUMN" NVARCHAR(3), 
"NULLABLE" NVARCHAR(1), 
"LOGICAL_POSITION" BIGINT,
primary key (LOGICAL_POSITION)
);

ALTER TABLE "replicate_io_audit_tbl_schema" ENABLE CHANGE_TRACKING;

CREATE TABLE  "replicate_io_audit_tbl_cons"
(
"SCHEMA_NAME" VARCHAR(128), 
"TABLE_NAME" VARCHAR(128), 
"COLUMN_NAME" VARCHAR(4000), 
"COL_POSITION" BIGINT, 
"CONSTRAINT_NAME" VARCHAR(128), 
"CONSTRAINT_TYPE" VARCHAR(1), 
"LOGICAL_POSITION" BIGINT,
primary key (LOGICAL_POSITION)
);

ALTER TABLE "replicate_io_audit_tbl_cons" ENABLE CHANGE_TRACKING;

CREATE OR ALTER TRIGGER "replicate_io_audit_ddl_trigger"
ON DATABASE
AFTER ALTER_TABLE
AS
        SET NOCOUNT ON
        DECLARE @data XML  
        DECLARE @operation NVARCHAR(30)  
        SET @data = EVENTDATA() 
        SET @operation = @data.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(30)') 
BEGIN
    INSERT INTO "replicate_io_audit_ddl" 
        ("CURRENT_USER", "SCHEMA_NAME", "TABLE_NAME", "TYPE", "OPERATION_TYPE", "SQL_TXT", "LOGICAL_POSITION")
        VALUES (
                        SUSER_NAME(), 
                        CONVERT(NVARCHAR(100), SCHEMA_NAME()),
                        @data.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(128)'),
                        @data.value('(/EVENT_INSTANCE/ObjectType)[1]', 'NVARCHAR(30)'),
                        @data.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(30)'),
                        @data.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(2000)'),
                        CHANGE_TRACKING_CURRENT_VERSION() );
END;

-- show the trigger for correctnesss
select m.definition from sys.all_sql_modules m inner join  sys.triggers t
on m.object_id = t.object_id
; 
