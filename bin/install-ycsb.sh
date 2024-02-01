#!/usr/bin/env bash

# download ycsb
if [ ! -d /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT ]; then
  sudo mkdir -p /opt/stage/ycsb && chown $(logname):$(logname) /opt/stage/ycsb
  pushd /opt/stage/ycsb >/dev/null
  [ ! -f ycsb-jdbc-binding-0.18.0-SNAPSHOT.tar.gz ]  && curl -O --location https://github.com/arcionlabs/YCSB/releases/download/arcion-24.01/ycsb-jdbc-binding-0.18.0-SNAPSHOT.tar.gz 
  [ -f ycsb-jdbc-binding-0.18.0-SNAPSHOT.tar.gz ] && gzip -dc *.gz | tar -xvf -
  popd >/dev/null
    echo "YCSB  /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT  downloaded"
else
    echo "YCSB  /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT  found"
fi

for jarfile in $(find /opt/stage/libs -name "*.jar" ! -name "log-*.jar"); do
  cp -v $jarfile /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/lib/.
done

[[ -z $(which tree) ]] && sudo apt-get update && sudo apt-get -y install tree
tree /opt/stage/ycsb