#!/usr/env/bin bash

orarac_tmux() {

WIN=${1:-orarac}

exists=$( tmux ls | grep "^${WIN}" )
if [ -z "${exists}" ]; then
    # windows
    tmux new-session -s $WIN -d
    tmux set -g mouse on
    tmux bind-key C-m set-option -g mouse \; display-message 'Mouse #{?mouse,on,off}'
    tmux rename-window -t $WIN.0 console
    tmux new-window    -t $WIN:1 -n utils 

    # windows 0 to run commands
                                    # 0.0 console
    tmux split-window -v -t $WIN:0  # 0.1 ycsb
    tmux split-window -v -t $WIN:0  # 0.2 arcion trace.log
    tmux split-window -v -t $WIN:0  # 0.3 arcion error.log
    tmux split-window -v -t $WIN:0  # 0.4 ssh to oracle

    
    # suggested commands add Enter
    tmux send-keys -t $WIN:0.0 "# ./arcdemo.sh full mysql postgresql"  
    tmux send-keys -t $WIN:0.1 "# /scripts/bin/ycsb-run.sh" 
    tmux send-keys -t $WIN:0.2 "# tail arcion trace.log"
    tmux send-keys -t $WIN:0.3 "# tail arcion error log"
    tmux send-keys -t $WIN:0.4 "# ssh to oracle"
 
    # activate $WIN:0
    tmux select-window -t $WIN:0.0
    tmux select-pane -t $WIN:0.0
    #
    echo "tmux session ready. new session created"
else
    echo "tmux session ready. session already exists"
fi
tmux attach-session -t $WIN
}
