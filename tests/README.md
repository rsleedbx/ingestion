to test a new YCSB

```
export SRCDB_ARC_USER=arcsrc
export SRCDB_ARC_PW=Passw0rd
export SRCDB_JDBC_DRIVER="org.postgresql.Driver"
export SRCDB_HOST=127.0.0.1
export SRCDB_PORT=5432
export SRCDB_JDBC_URL="jdbc:postgresql://${SRCDB_HOST}:${SRCDB_PORT}/${SRCDB_ARC_USER}?autoReconnect=true&sslmode=disable&ssl=false"   

rm -rf /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT; tar -xvf jdbc/target/ycsb-jdbc-binding-0.18.0-SNAPSHOT.tar.gz -C /opt/stage/ycsb; find /opt/stage/libs -type f | grep -v log4j | xargs -I{} cp -v {} /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/lib

JAVA_OPTS="-XX:MinRAMPercentage=${y_MinRAMPercentage:-1.0} -XX:MaxRAMPercentage=${y_MaxRAMPercentage:-1.0}"       java -cp $(find lib -type f | paste -sd:) site.ycsb.db.JdbcDBCreateTable -n "${table_name}"         -p db.driver=$SRCDB_JDBC_DRIVER         -p db.url=$SRCDB_JDBC_URL         -p db.user="$SRCDB_ARC_USER"         -p db.passwd="$SRCDB_ARC_PW"         -p jdbc.ycsbkeyprefix=false         -p jdbc.create_table_ddl="create table t1(key int);"


JAVA_OPTS="-XX:MinRAMPercentage=${y_MinRAMPercentage:-1.0} -XX:MaxRAMPercentage=${y_MaxRAMPercentage:-1.0}"       java -cp $(find lib -type f | paste -sd:) site.ycsb.db.JdbcDBCreateTable -n "t1"         -p db.driver=$SRCDB_JDBC_DRIVER         -p db.url=$SRCDB_JDBC_URL         -p db.user="$SRCDB_ARC_USER"         -p db.passwd="$SRCDB_ARC_PW"         -p jdbc.ycsbkeyprefix=false     

```