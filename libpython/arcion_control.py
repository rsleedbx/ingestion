
from ipywidgets import widgets, HBox, VBox, Label

def show_arcion_config():
    global repl_mode
    global cdc_mode
    global snapshot_threads
    global realtime_threads
    global delta_threads

    repl_mode = widgets.Dropdown(options=['snapshot', 'real-time', 'full'],value='snapshot',
        description='Replication:',
    )
    cdc_mode = widgets.Dropdown(options=['change', 'cdc'],value='change',
        description='CDC Method:',
    )

    snapshot_threads = widgets.BoundedIntText(value=1,min=1,max=8,
        description='Snapshot Threads:',
    )

    realtime_threads = widgets.BoundedIntText(value=1,min=1,max=8,
        description='Real Time Threads:',
    )    

    delta_threads = widgets.BoundedIntText(value=1,min=1,max=8,
        description='Delta Snapshot Threads:',
    )    