CREATE TABLE ${table_name} (
YCSB_KEY INT,
$( seq 1 $(( ${y_fieldcount:-10} )) | awk '{printf "FIELD%d text,\n", $1-1}' )
PRIMARY KEY (YCSB_KEY)
)
go