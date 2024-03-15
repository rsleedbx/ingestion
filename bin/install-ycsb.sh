#!/usr/bin/env bash

LOGNAME=$(logname 2>/dev/null)
LOGNAME=${LOGNAME:-root}

if [ ! -d /opt/stage/ycsb ]; then
    sudo mkdir -p /opt/stage/ycsb && chown "${LOGNAME}" /opt/stage/ycsb
fi

# download ycsb
if [ ! -d /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT ]; then
  pushd /opt/stage/ycsb >/dev/null
  [ ! -f ycsb-jdbc-binding-0.18.0-SNAPSHOT.tar.gz ]  && curl -O --location https://github.com/arcionlabs/YCSB/releases/download/arcion-24.03/ycsb-jdbc-binding-0.18.0-SNAPSHOT.tar.gz
  [ -f ycsb-jdbc-binding-0.18.0-SNAPSHOT.tar.gz ] && gzip -dc *.gz | tar -xvf -
  popd >/dev/null
    echo "YCSB  /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT  downloaded"
else
    echo "YCSB  /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT  found"
fi

# numfmt from coreutils
if [ -z "$(dpkg -l coreutils 2>/dev/null)" ]; then 
    sudo apt-get update -y
    sudo apt-get install -y coreutils
else
    echo "numfmt found"
fi

# bc
if [ -z "$(dpkg -l bc 2>/dev/null)" ]; then 
    sudo apt-get update -y
    sudo apt-get install -y bc
else
    echo "bc found"
fi


for inst in $(find /opt/stage/ycsb -name "lib"); do
  dir="$(dirname $inst)/lib"
  echo "checking jar(s) in $dir for updates"
  for jarfile in $(find /opt/stage/libs -name "*.jar" ! -name "log-*.jar"); do
    cp -vu $jarfile $dir/.
  done
done
