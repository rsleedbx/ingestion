CREATE LOGIN ${DB_ARC_USER} WITH PASSWORD = '${DB_ARC_PW}'
go

create database ${DB_DB}
go

use ${DB_DB}
go

CREATE USER ${DB_ARC_USER} FOR LOGIN ${DB_ARC_USER} WITH DEFAULT_SCHEMA=dbo
go

ALTER ROLE db_owner ADD MEMBER ${DB_ARC_USER}
go

ALTER ROLE db_ddladmin ADD MEMBER ${DB_ARC_USER}
go

alter user ${DB_ARC_USER} with default_schema=dbo
go

ALTER LOGIN ${DB_ARC_USER} WITH DEFAULT_DATABASE=[${DB_DB}]
go

-- required for DDL CDC
EXEC sys.sp_cdc_enable_db 
go