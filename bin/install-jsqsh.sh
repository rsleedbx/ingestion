#!/usr/bin/env bash

if [ ! -d /opt/stage/bin ]; then
    sudo mkdir -p /opt/stage/bin && sudo chown $(logname):$(logname) /opt/stage/bin
fi

if [ ! -d /opt/stage/bin/jsqsh-dist-3.0-SNAPSHOT ]; then
    cd /opt/stage/bin \
        && wget https://github.com/arcionlabs/jsqsh/releases/download/arcionlabs/jsqsh-dist-3.0-SNAPSHOT-bin.tar.gz \
        && gzip -dc jsqsh* | tar -xvf - \
        && rm *.tar.gz
fi

# required for jsqsh to find JDBC drivers
if [ -z "$(which jsqsh)" ]; then
    export PATH=/opt/stage/bin/jsqsh-dist-3.0-SNAPSHOT/bin:$PATH
fi

export CLASSPATH=$(find /opt/stage/libs -name "*.jar" ! -name "log" | paste -s -d":")    