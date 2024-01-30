#!/usr/bin/env bash

if [ ! -f /opt/stage/arcion/replicant-cli/bin/replicant ]; then
  sudo mkdir -p /opt/stage/arcion; chown "$(logname)" /opt/stage/arcion
  cd /opt/stage/arcion && curl -O --location https://arcion-releases.s3.us-west-1.amazonaws.com/general/replicant/replicant-cli-23.09.29.11.zip
  unzip -q replicant-cli-*.zip
  rm replicant-cli-*.zip
  echo "arcion  /opt/stage/arcion/replicant-cli/bin/replicant downloaded"
else
  echo "arcion  /opt/stage/arcion/replicant-cli/bin/replicant found"
fi

# copy the jar and jdbc
for inst in $(find /opt/stage/arcion -name "replicant" -o -name "replicate"); do
  echo $inst 
  dir=$(dirname $(dirname $inst))

  for jarfile in $(find /opt/stage/libs/ -name "DatabricksJDBC42.jar" -o -name "SparkJDBC42.jar"  -o -name "log4j-*.jar" -o -name "ojdbc8.jar"); do
    cp -v $jarfile ${dir}/lib
  done
done 

