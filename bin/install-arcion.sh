#!/usr/bin/env bash

LOGNAME=$(logname 2>/dev/null)
LOGNAME=${LOGNAME:-root}
ARCION_BASEDIR=${ARCION_BASEDIR:-/opt/stage/arcion}

if [ ! -d "$ARCION_BASEDIR" ]; then
    sudo mkdir -p $ARCION_BASEDIR && sudo chown "${LOGNAME}" $ARCION_BASEDIR
fi

ARCION_DOWNLOAD_URL=${ARCION_DOWNLOAD_URL:-https://arcion-releases.s3.us-west-1.amazonaws.com/general/replicant/replicant-cli-24.01.25.7.zip}
ARCION_DIRNAME=$( basename $ARCION_DOWNLOAD_URL .zip  )
ARCION_HOME="${ARCION_BASEDIR}/${ARCION_DIRNAME}"

# check if downloaded and unzipped
ARCION_BIN="$( find ${ARCION_HOME} -maxdepth 4 -name replicate -o -name replicant 2>/dev/null)" 
if [[ ( -z "$ARCION_BIN" ) || ( ! -f "$ARCION_BIN" ) ]]; then
  mkdir -p $ARCION_HOME
  cd $ARCION_HOME
  curl -O --location $ARCION_DOWNLOAD_URL 
  unzip -q *-cli-*.zip && rm *-cli-*.zip
  echo "arcion  $ARCION_BIN downloaded"
else
  echo "arcion  $ARCION_BIN found"
fi

# copy the jar and jdbc
for inst in $(find $ARCION_BASEDIR -name "replicant" -o -name "replicate"); do
  dir="$(dirname $(dirname $inst))/lib"
  echo "checking jar(s) in $dir for updates"

  # SQL Server is included
  for jarfile in $(find /opt/stage/libs/ -name "DatabricksJDBC42.jar" -o -name "SparkJDBC42.jar"  -o -name "log4j-*.jar" -o -name "ojdbc8.jar"); do
    # -u update if source is newer
    # -v show files being updated
    cp -vu $jarfile ${dir}/.
  done
done 

# setup the license
if [ ! -f $ARCION_BASEDIR/replicant.lic ]; then
  if [ -n "$ARCION_LICENSE" ]; then
    echo "setting $ARCION_BASEDIR/replicant.lic from \$ARCION_LICENSE"
    # try if gzip
    echo "$ARCION_LICENSE" | base64 -d | gzip -d > ${ARCION_BASEDIR}/replicant.lic 2>/dev/null
    # try non gzip
    if [ "$?" != 0 ]; then
        echo "$ARCION_LICENSE" | base64 -d > ${ARCION_BASEDIR}/replicant.lic 2>/dev/null
    fi
    if [ -s ${ARCION_BASEDIR}/replicant.lic ]; then 
      cat ${ARCION_BASEDIR}/replicant.lic
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
