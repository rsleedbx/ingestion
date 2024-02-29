#!/usr/bin/env bash

LOGNAME=$(logname 2>/dev/null)
LOGNAME=${LOGNAME:-root}
ARCION_HOME=${ARCION_HOME:-/opt/stage/arcion}

ARCION_DOWNLOAD_URL=${ARCION_DOWNLOAD_URL:-https://arcion-releases.s3.us-west-1.amazonaws.com/general/replicant/replicant-cli-24.01.25.7.zip}
ARCION_VER=$(echo $ARCION_DOWNLOAD_URL | sed 's/.*cli-\(.*\)\.zip$/\1/' )
ARCION_BIN="${ARCION_HOME}/${ARCION_VER}"

if [ ! -d $ARCION_HOME ]; then
    sudo mkdir -p $ARCION_HOME && chown "${LOGNAME}" $ARCION_HOME
fi

if [ ! -d $ARCION_BIN ]; then
  mkdir -p $ARCION_BIN
  cd $ARCION_BIN
  curl -O --location $ARCION_DOWNLOAD_URL 
  unzip -q replicant-cli-*.zip && rm replicant-cli-*.zip
  echo "arcion  $ARCION_BIN downloaded"
else
  echo "arcion  $ARCION_BIN found"
fi

# copy the jar and jdbc
for inst in $(find $ARCION_HOME -name "replicant" -o -name "replicate"); do
  dir="$(dirname $(dirname $inst))/lib"
  echo "checking jar(s) in $dir for updates"

  for jarfile in $(find /opt/stage/libs/ -name "DatabricksJDBC42.jar" -o -name "SparkJDBC42.jar"  -o -name "log4j-*.jar" -o -name "ojdbc8.jar"); do
    # -u update if source is newer
    # -v show files being updated
    cp -vu $jarfile ${dir}/.
  done
done 

# setup the license
if [ ! -f $ARCION_HOME/replicant.lic ]; then
  if [ -n "$ARCION_LICENSE" ]; then
    echo "setting $ARCION_HOME/replicant.lic from \$ARCION_LICENSE"
    # try if gzip
    echo "$ARCION_LICENSE" | base64 -d | gzip -d > ${ARCION_HOME}/replicant.lic 2>/dev/null
    # try non gzip
    if [ "$?" != 0 ]; then
        echo "$ARCION_LICENSE" | base64 -d > ${ARCION_HOME}/replicant.lic 2>/dev/null
    fi
    if [ -s ${ARCION_HOME}/replicant.lic ]; then 
      cat ${ARCION_HOME}/replicant.lic
    else
      echo "Error: ARCION_LICENSE not valid"
      exit 1
    fi
  else
    echo "Error: Arcion license not found and $ARCION_LICENSE not set"
    exit 2
  fi
else
  echo "Arcion license found"
fi
