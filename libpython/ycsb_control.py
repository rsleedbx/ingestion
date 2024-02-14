from ipywidgets import widgets, HBox, VBox, Label

def show_ycsb_config():
    global ycsb_row1
    global ycsb_row2
    global sparse_cnt
    global sparse_fieldcount
    global sparse_fieldlength
    global sparse_tps
    global sparse_threads
    global sparse_recordcount

    global dense_cnt
    global dense_fieldcount
    global dense_fieldlength
    global dense_tps
    global dense_threads
    global dense_recordcount

    sparse_cnt = widgets.BoundedIntText(value=1,min=1,max=100,
        description='Table Cnt:',
    )
    sparse_fieldcount = widgets.BoundedIntText(value=50,min=0,max=9000,
        description='# of Fields:',
    )
    sparse_fieldlength = widgets.BoundedIntText(value=10,min=1,max=1000,
        description='Field Len:',
    )
    
    sparse_tps = widgets.BoundedIntText(value=1,min=0,max=1000,
        description='TPS:',
    )
    sparse_threads = widgets.BoundedIntText(value=1,min=1,max=8,
        description='Threads:',
    )
    sparse_recordcount = widgets.Text(value="1M",
        description='Rec Cnt:',
    )

    dense_cnt = widgets.BoundedIntText(value=1,min=1,max=100,
        description='Table Cnt:',
    )
    dense_fieldcount = widgets.BoundedIntText(value=10,min=0,max=9000,
        description='# of Fields:',
    )
    dense_fieldlength = widgets.BoundedIntText(value=100,min=1,max=1000,
        description='Field Len:',
    )
    dense_recordcount = widgets.Text(value="100K",
        description='Rec Cnt:',
    )
    
    dense_tps = widgets.BoundedIntText(value=1,min=0,max=1000,
        description='TPS:',
    )
    dense_threads = widgets.BoundedIntText(value=1,min=1,max=8,
        description='Threads:',
    )


