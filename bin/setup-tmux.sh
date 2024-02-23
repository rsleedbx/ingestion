#!/usr/bin/env bash

# to delete
#   tmux kill-session -t ${SESSION_NAME}
setup_tmux() {

local LOGNAME=$(logname 2>/dev/null)
local LOGNAME=${LOGNAME:-root}
local SESSION_NAME=${1:-$LOGNAME}

exists=$( tmux ls 2>/dev/null | grep "^${SESSION_NAME}" )
if [ -z "${exists}" ]; then
    # windows
    tmux new-session -s ${SESSION_NAME} -d
    tmux set -g mouse on
    tmux bind-key C-m set-option -g mouse \; display-message 'Mouse #{?mouse,on,off}'
    tmux rename-window -t ${SESSION_NAME}:0 console
    tmux new-window    -t ${SESSION_NAME}:1 -n "trace"
    tmux new-window    -t ${SESSION_NAME}:2 -n "error"
    tmux new-window    -t ${SESSION_NAME}:3 -n "logdir"
    tmux new-window    -t ${SESSION_NAME}:4 -n "ycsb"
    tmux new-window    -t ${SESSION_NAME}:5 -n "sqluser"
    tmux new-window    -t ${SESSION_NAME}:6 -n "sqlroot"

    # suggested commands add Enter
    tmux send-keys -t ${SESSION_NAME}:0 "htop" enter  
    tmux send-keys -t ${SESSION_NAME}:1 "# trace.log" 
    tmux send-keys -t ${SESSION_NAME}:2 "# tail arcion trace.log"
    tmux send-keys -t ${SESSION_NAME}:3 "# tail arcion error log"
    tmux send-keys -t ${SESSION_NAME}:4 "# ycsb"
    tmux send-keys -t ${SESSION_NAME}:5 "# sqluser"
    tmux send-keys -t ${SESSION_NAME}:6 "# sqluser"
 
    # activate ${SESSION_NAME}:0
    tmux select-window -t ${SESSION_NAME}:0
    #
    echo "tmux session ready. new session $SESSION_NAME created"
else
    echo "tmux session ready. session $SESSION_NAME already exists"
fi
tmux attach-session -t ${SESSION_NAME}
}
