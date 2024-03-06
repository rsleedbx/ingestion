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
