#!/usr/bin/env bash

# env check
(return 0 2>/dev/null) && export SCRIPT_SOURCED=1 || export SCRIPT_SOURCED=0

if [ -z "${BASH_SOURCE}" ]; then 
  echo "Please invoke using bash" 
  if (( SCRIPT_SOURCED == 1 )); then 
    return 1 
  else 
    exit 1
  fi 
fi
PROG_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. $PROG_DIR/utils.sh

# actual code 
PROM_BASEDIR=${PROM_BASEDIR:-/opt/stage/prom}
if [ ! -d "$PROM_BASEDIR" ]; then
    sudo mkdir -p $PROM_BASEDIR && sudo chown "${LOGNAME}" $PROM_BASEDIR
fi

if [ ! -x $PROM_BASEDIR/prometheus-2.50.1.linux-amd64/prometheus ]; then
  echo "prometheus being downloaded"
  pushd $PROM_BASEDIR >/dev/null
  curl -O --location https://github.com/prometheus/prometheus/releases/download/v2.50.1/prometheus-2.50.1.linux-amd64.tar.gz
  gzip -dc *.tar.gz | tar -xvf -
  rm -rf *.tar.gz
  popd >/dev/null
else
  echo "prometheus already downloaded"
fi

if [ ! -x $PROM_BASEDIR/node_exporter-1.7.0.linux-amd64/node_exporter ]; then
  echo "prometheus node_exporter being downloaded"
  pushd $PROM_BASEDIR >/dev/null
  curl -O --location https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
  gzip -dc node_exporter*.tar.gz | tar -xvf -
  rm -rf node_exporter*.tar.gz
  popd >/dev/null
else
  echo "prometheus node_exporter already downloaded"
fi

# https://prometheus.io/docs/instrumenting/exporters/
# https://github.com/burningalchemist/sql_exporter
# curl http://localhost:9399/metrics
if [ ! -x $PROM_BASEDIR/node_exporter-1.7.0.linux-amd64/node_exporter ]; then
  echo "prometheus sql_exporter being downloaded"
  pushd $PROM_BASEDIR >/dev/null
  curl -O --location https://github.com/burningalchemist/sql_exporter/releases/download/0.14.0/sql_exporter-0.14.0.linux-amd64.tar.gz
  gzip -dc sql_exporter*.tar.gz | tar -xvf -
  rm -rf sql_exporter*.tar.gz
  popd >/dev/null
else
  echo "prometheus sql_exporter already downloaded"
fi