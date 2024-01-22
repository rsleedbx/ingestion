$!/usr/env/bin bash

if [ ! -f /opt/stage/arcion/replicant-cli/bin/replicant ]; then
  sudo mkdir -p /opt/stage/arcion; chown $(logname):$(logname) /opt/stage/arcion
    cd /opt/stage/arcion && curl -O --location https://arcion-releases.s3.us-west-1.amazonaws.com/general/replicant/replicant-cli-23.09.29.11.zip
    unzip -q replicant-cli-*.zip
    rm replicant-cli-*.zip
fi
/opt/stage/arcion/replicant-cli/bin/replicant version