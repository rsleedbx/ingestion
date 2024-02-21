#!/usr/bin/env python3
import fileinput
import os
y_fieldcount=10
try:
    y_fieldcount = int(os.environ["y_fieldcount"])
except:
    pass

print ("14.0")                  # version
print (f"{y_fieldcount + 1}")   # total number of fields + primary key
if y_fieldcount==0:
    print ('1 SQLCHAR 0 0 "\\n" 1 YCSB_KEY ""');
else:
    print ('1 SQLCHAR 0 0 "," 1 YCSB_KEY ""');
for i in range(1,y_fieldcount+1):
    if i<y_fieldcount:
        print(f'{i+1} SQLCHAR 0 0 "," {i+1} FIELD{i-1} SQL_Latin1_General_CP1_CI_AS')
    else:
        print(f'{i+1} SQLCHAR 0 0 "\\n" {i+1} FIELD{i-1} SQL_Latin1_General_CP1_CI_AS')