from ipywidgets import widgets, HBox, VBox, Label

def show_ycsb_config():
    sparse_cnt = widgets.BoundedIntText(value=1,min=1,max=100,
        description='Instances:',
    )
    sparse_tps = widgets.BoundedIntText(value=1,min=0,max=1000,
        description='TPS:',
    )
    sparse_fields = widgets.BoundedIntText(value=10,min=0,max=9000,
        description='# of Fields:',
    )
    sparse_field_len = widgets.BoundedIntText(value=100,min=1,max=1000,
        description='Field Len:',
    )

    dense_cnt = widgets.BoundedIntText(value=1,min=1,max=100,
        description='Instances:',
    )
    dense_tps = widgets.BoundedIntText(value=1,min=0,max=1000,
        description='TPS:',
    )
    dense_fields = widgets.BoundedIntText(value=10,min=0,max=9000,
        description='# of Fields:',
    )
    dense_field_len = widgets.BoundedIntText(value=100,min=1,max=1000,
        description='Field Len:',
    )
    row1=HBox([Label('Sparse'), sparse_cnt, sparse_tps, sparse_fields, sparse_field_len])
    row2=HBox([Label('Dense'),  dense_cnt,  dense_tps,  dense_fields, dense_field_len])
    return(VBox([row1,row2]))

