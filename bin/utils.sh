#!/usr/bin/env bash

LOGNAME=$(logname 2>/dev/null)
LOGNAME=${LOGNAME:-root}

# MACHINE
setMachineType() {
    # osx=arm64
    # linux=x86_64
    [ -z "${MACHINE}" ] && export MACHINE="$(uname -m)"    
    case ${MACHINE} in
        arm64|x86_64) echo "$MACHINE detected.";; 
        *) abort "MACHINE $MACHINE not handled.";;
    esac
    # darwin=osx
    # linux
    [ -z "${OS_TYPE}" ] && export OS_TYPE="$(uname -o)"    
}

#
kill_recurse() {
    if [ -z "${1}" ]; then return 0; fi
    echo kill $1
    cpids=$(pgrep -P $1 | xargs)
    for cpid in $cpids;
    do
        kill_recurse $cpid
    done
    kill -9 $1 2>/dev/null
}
