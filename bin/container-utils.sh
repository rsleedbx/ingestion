#!/usr/bin/env bash

port_mysql() {
    local port=${1:-3306}
    podman port --all | grep "${port}/tcp" | head -n 1 | cut -d ":" -f 2 
}