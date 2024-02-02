#!/usr/bin/env bash

LOGNAME=$(logname 2>/dev/null)
LOGNAME=${LOGNAME:-root}

if [ ! -d /opt/stage/arcion ]; then
    sudo mkdir -p /opt/stage/arcion && chown "${LOGNAME}" /opt/stage/arcion
fi

if [ ! -d /opt/stage/arcion/replicant-cli/bin ]; then
  cd /opt/stage/arcion && curl -O --location https://arcion-releases.s3.us-west-1.amazonaws.com/general/replicant/replicant-cli-24.01.25.1.zip
  unzip -q replicant-cli-*.zip
  rm replicant-cli-*.zip
  echo "arcion  /opt/stage/arcion/replicant-cli/bin/replicant downloaded"
else
  echo "arcion  /opt/stage/arcion/replicant-cli/bin/replicant found"
fi

# copy the jar and jdbc
for inst in $(find /opt/stage/arcion -name "replicant" -o -name "replicate"); do
  dir="$(dirname $(dirname $inst))/lib"
  echo "checking jar(s) in $dir for updates"

  for jarfile in $(find /opt/stage/libs/ -name "DatabricksJDBC42.jar" -o -name "SparkJDBC42.jar"  -o -name "log4j-*.jar" -o -name "ojdbc8.jar"); do
    # -u update if source is newer
    # -v show files being updated
    cp -vu $jarfile ${dir}/.
  done
done 

