#!/usr/bin/env bash

# download ycsb
if [ ! -d /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT ]; then
  sudo mkdir -p /opt/stage/ycsb && chown $(logname):$(logname) /opt/stage/ycsb
  pushd /opt/stage/ycsb >/dev/null
  [ ! -f ycsb-jdbc-binding-0.18.0-SNAPSHOT.tar.gz ]  && curl -O --location https://github.com/arcionlabs/YCSB/releases/download/arcion-23.07/ycsb-jdbc-binding-0.18.0-SNAPSHOT.tar.gz 
  [ -f ycsb-jdbc-binding-0.18.0-SNAPSHOT.tar.gz ] && gzip -dc *.gz | tar -xvf -
  popd >/dev/null
fi

cp -v /opt/stage/libs/*.jar /opt/stage/ycsb/ycsb-jdbc-binding-0.18.0-SNAPSHOT/lib/.

[[ -z $(which tree) ]] && sudo apt-get update && sudo apt-get -y install tree
tree /opt/stage/ycsb