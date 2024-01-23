#!/usr/bin/env bash

sudo mkdir -p /opt/stage/bin && sudo chown $(logname):$(logname) /opt/stage/bin

cd /opt/stage/bin \
    && wget https://github.com/arcionlabs/jsqsh/releases/download/arcionlabs/jsqsh-dist-3.0-SNAPSHOT-bin.tar.gz \
    && gzip -dc jsqsh* | tar -xvf - \
    && rm *.tar.gz

export CLASSPATH=$(find /opt/stage/libs -name "*.jar" ! -name "log" | paste -s -d":")    