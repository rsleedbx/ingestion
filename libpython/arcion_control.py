
from ipywidgets import widgets, HBox, VBox, Label

def show_arcion_config():
    global repl_mode
    global cdc_mode
    repl_mode = widgets.Dropdown(options=['snapshot', 'real-time', 'full'],value='snapshot',
        description='Replication:',
    )
    cdc_mode = widgets.Dropdown(options=['change', 'cdc'],value='change',
        description='CDC Method:',
    )
