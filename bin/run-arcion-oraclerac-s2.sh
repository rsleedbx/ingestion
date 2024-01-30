#!/usr/env/bin bash

export ARCION_HOME=/opt/stage/arcion/replicate-cli-23.05.31.29
$ARCION_HOME/bin/replicate full src.yaml dst_s2.yaml \
  --overwrite --id $$ --replace \
  --general general.yaml \
  --extractor extractor.yaml \
  --filter filter.yaml \
  --applier applier_s2.yaml \
  --map map_s2.yaml


export ARCION_HOME=/opt/stage/arcion/replicate-cli-23.05.31.29
$ARCION_HOME/bin/replicate snapshot src_pdb.yaml dst_s2.yaml \
  --overwrite --id $$ --replace \
  --general general.yaml \
  --extractor extractor.yaml \
  --filter filter.yaml \
  --applier applier_s2.yaml \
  --map map_s2.yaml