#!/usr/bin/env bash

LOGNAME=$(logname 2>/dev/null)
LOGNAME=${LOGNAME:-root}

if [ ! -d /opt/stage/bin ]; then
    sudo mkdir -p /opt/stage/bin && sudo chown "${LOGNAME}" /opt/stage/bin
fi

if [ ! -d /opt/stage/bin/jsqsh-dist-3.0-SNAPSHOT ]; then
    cd /opt/stage/bin \
        && wget https://github.com/arcionlabs/jsqsh/releases/download/arcion-24.02/jsqsh-dist-3.0-SNAPSHOT-bin.tar.gz \
        && gzip -dc jsqsh* | tar -xvf - \
        && rm *.tar.gz
    echo "jsqsh  /opt/stage/bin/jsqsh-dist-3.0-SNAPSHOT downloaded"
else
    echo "jsqsh  /opt/stage/bin/jsqsh-dist-3.0-SNAPSHOT found"
fi

for jarfile in $(find /opt/stage/libs -name "*.jar" ! -name "log-*.jar"); do
  cp -v $jarfile /opt/stage/bin/jsqsh-dist-3.0-SNAPSHOT/share/jsqsh
done

# required for jsqsh to find JDBC drivers
if [ -z "$(which jsqsh)" ]; then
    export PATH=/opt/stage/bin/jsqsh-dist-3.0-SNAPSHOT/bin:$PATH
    echo <<EOF
Add the following into your .profile

export PATH=/opt/stage/bin/jsqsh-dist-3.0-SNAPSHOT/bin:$PATH
EOF
fi

# export CLASSPATH=$(find /opt/stage/libs -name "*.jar" ! -name "log" | paste -s -d ":" -) 