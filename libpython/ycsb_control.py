from ipywidgets import widgets, HBox, VBox, Label

def show_ycsb_config():
    global ycsb_row1
    global ycsb_row2
    global sparse_cnt
    global sparse_fields
    global sparse_field_len
    global sparse_tps
    global sparse_threads

    global dense_cnt
    global dense_fields
    global dense_field_len
    global dense_tps
    global dense_threads

    sparse_cnt = widgets.BoundedIntText(value=1,min=1,max=100,
        description='Table Count:',
    )
    sparse_fields = widgets.BoundedIntText(value=10,min=0,max=9000,
        description='# of Fields:',
    )
    sparse_field_len = widgets.BoundedIntText(value=100,min=1,max=1000,
        description='Field Len:',
    )
    
    sparse_tps = widgets.BoundedIntText(value=1,min=0,max=1000,
        description='TPS:',
    )
    sparse_threads = widgets.BoundedIntText(value=1,min=1,max=8,
        description='Threads:',
    )

    dense_cnt = widgets.BoundedIntText(value=1,min=1,max=100,
        description='Table Count:',
    )
    dense_fields = widgets.BoundedIntText(value=10,min=0,max=9000,
        description='# of Fields:',
    )
    dense_field_len = widgets.BoundedIntText(value=100,min=1,max=1000,
        description='Field Len:',
    )
    
    dense_tps = widgets.BoundedIntText(value=1,min=0,max=1000,
        description='TPS:',
    )
    dense_threads = widgets.BoundedIntText(value=1,min=1,max=8,
        description='Threads:',
    )


